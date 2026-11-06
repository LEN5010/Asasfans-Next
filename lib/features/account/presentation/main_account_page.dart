import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../shared/widgets/app_controls.dart';
import '../../../shared/widgets/app_page_bar.dart';
import '../application/main_account_providers.dart';
import '../domain/main_account.dart';
import 'main_account_tile.dart';

enum _Mode { login, register, reset }

/// Native sign-in, registration, email binding and password reset for the
/// dynamic_asoul account. An account without a verified email can only bind
/// one or sign out.
class MainAccountPage extends ConsumerStatefulWidget {
  const MainAccountPage({super.key});
  @override
  ConsumerState<MainAccountPage> createState() => _MainAccountPageState();
}

class _MainAccountPageState extends ConsumerState<MainAccountPage> {
  var _mode = _Mode.login;
  final _account = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _code = TextEditingController();
  String? _codeSentTo;
  String? _signupSentTo;
  bool _resetSent = false;
  bool _changingEmail = false;
  String? _notice;
  String? _formError;
  bool _showPassword = false;

  /// Seconds before another code may be requested.
  int _cooldown = 0;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // An address verified on the website reaches this device here.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final account = ref.read(mainAccountControllerProvider);
      if (mounted && !account.loading && account.session?.user.email == null) {
        if (account.session != null) account.refresh(_chooseImport);
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    for (final controller in [
      _account,
      _username,
      _email,
      _password,
      _confirm,
      _code,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<bool> _chooseImport() async =>
      await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('本机收藏'),
          actions: [
            AppButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('从空白开始'),
            ),
            AppButton(
              selected: true,
              onPressed: () => Navigator.pop(context, true),
              child: const Text('把本机收藏带进这个账号'),
            ),
          ],
        ),
      ) ??
      false;

  void _clearSecrets() {
    _password.clear();
    _confirm.clear();
    _code.clear();
  }

  /// Applies [done] when the action succeeded; the controller reports failures.
  Future<void> _act(Future<bool> Function() action, VoidCallback done) async {
    setState(() {
      _notice = null;
      _formError = null;
    });
    if (await action() && mounted) setState(done);
  }

  void _startCooldown() {
    _ticker?.cancel();
    _cooldown = 60;
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _cooldown--);
      if (_cooldown <= 0) timer.cancel();
    });
  }

  void _switch(_Mode mode) => setState(() {
    _mode = mode;
    _resetSent = false;
    _notice = null;
    _formError = null;
  });

  bool _matching() {
    if (_password.text == _confirm.text) return true;
    setState(() => _formError = '两次输入的密码不一致');
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(mainAccountControllerProvider);
    final session = account.session;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const AppPageBar(title: Text('账号')),
      body: Builder(
        builder: (context) => Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: AutofillGroup(
              child: ListView(
                padding: pageInsets(context, top: 8),
                children: [
                  if (account.loading)
                    const Padding(
                      padding: EdgeInsets.only(top: 48),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (session == null)
                    _card(_signIn(account.busy))
                  else ...[
                    if (session.user.email != null)
                      _card(_accountSummary(session.user, account.busy)),
                    if (session.user.email == null || _changingEmail) ...[
                      if (session.user.email != null)
                        const SizedBox(height: AppTokens.sectionGap),
                      _card(_bindEmail(session.user, account.busy)),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(List<Widget> children) => AppCard(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < children.length; index++) ...[
          if (index > 0) const SizedBox(height: 14),
          children[index],
        ],
      ],
    ),
  );

  /// The failure or the last confirmation, inside the form it belongs to.
  Widget? _message() {
    final account = ref.read(mainAccountControllerProvider);
    final error = _formError ?? account.error;
    final text = error ?? _notice;
    if (text == null) return null;
    final colors = Theme.of(context).colorScheme;
    final color = error != null ? colors.error : colors.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(
            error != null ? Icons.error_outline : Icons.check_circle_outline,
            size: 18,
            color: color,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: color),
          ),
        ),
      ],
    );
  }

  Widget _title(String text) => Text(
    text,
    style: Theme.of(
      context,
    ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
  );

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool secret = false,
    TextInputType? keyboard,
    Iterable<String>? autofill,
    int? maxLength,
    Widget? trailing,
  }) => TextField(
    controller: controller,
    obscureText: secret && !_showPassword,
    keyboardType: keyboard,
    autofillHints: autofill,
    maxLength: maxLength,
    inputFormatters: keyboard == TextInputType.number
        ? [FilteringTextInputFormatter.digitsOnly]
        : null,
    decoration: InputDecoration(
      hintText: label,
      counterText: '',
      prefixIcon: Icon(icon, size: 20),
      suffixIcon: secret
          ? AppButton.icon(
              tooltip: _showPassword ? '隐藏密码' : '显示密码',
              onPressed: () => setState(() => _showPassword = !_showPassword),
              icon: Icon(
                _showPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            )
          : trailing == null
          ? null
          : Padding(padding: const EdgeInsets.only(right: 6), child: trailing),
    ),
  );

  /// A code field with its send button inside, counting down after a send.
  Widget _codeField(bool busy, bool sent, VoidCallback send) => _field(
    _code,
    '邮箱验证码',
    Icons.pin_outlined,
    keyboard: TextInputType.number,
    maxLength: 6,
    trailing: TextButton(
      style: TextButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.primary,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.inputRadius - 4),
        ),
      ),
      onPressed: busy || _cooldown > 0 ? null : send,
      child: Text(
        _cooldown > 0
            ? '$_cooldown 秒'
            : sent
            ? '重新发送'
            : '发送验证码',
      ),
    ),
  );

  /// The form's one main action, the width of the form.
  Widget _primary(String label, bool busy, VoidCallback onPressed) => SizedBox(
    height: 48,
    child: FilledButton(
      onPressed: busy ? null : onPressed,
      child: busy
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(
              label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
    ),
  );

  Widget _link(String label, VoidCallback? onPressed) => Center(
    child: AppButton(onPressed: onPressed, child: Text(label)),
  );

  List<Widget> _signIn(bool busy) {
    final controller = ref.read(mainAccountControllerProvider);
    final message = _message();
    if (_mode == _Mode.reset) {
      return [
        _title('重设密码'),
        _field(
          _account,
          '用户名或邮箱',
          Icons.person_outline,
          autofill: [AutofillHints.username],
        ),
        _codeField(
          busy,
          _resetSent,
          () => _act(
            () => controller.requestPasswordReset(_account.text.trim()),
            () {
              _resetSent = true;
              _startCooldown();
              _notice = '如果该账号已绑定邮箱，验证码已发送到邮箱';
            },
          ),
        ),
        _field(
          _password,
          '新密码',
          Icons.lock_outline,
          secret: true,
          autofill: [AutofillHints.newPassword],
        ),
        _field(_confirm, '确认新密码', Icons.lock_outline, secret: true),
        ?message,
        _primary('重设密码', busy, () {
          if (!_matching()) return;
          _act(
            () => controller.confirmPasswordReset(
              _account.text.trim(),
              _code.text.trim(),
              _password.text,
            ),
            () {
              _clearSecrets();
              _resetSent = false;
              _mode = _Mode.login;
              _notice = '密码已重设，请用新密码登录';
            },
          );
        }),
        _link('返回登录', busy ? null : () => _switch(_Mode.login)),
      ];
    }
    final register = _mode == _Mode.register;
    return [
      AppSegments<_Mode>(
        values: const [_Mode.login, _Mode.register],
        labelOf: (mode) => mode == _Mode.login ? '登录' : '注册',
        selected: _mode,
        onChanged: busy ? null : _switch,
      ),
      if (register) ...[
        _field(
          _username,
          '用户名',
          Icons.person_outline,
          autofill: [AutofillHints.newUsername],
        ),
        _field(
          _email,
          '邮箱',
          Icons.mail_outline,
          keyboard: TextInputType.emailAddress,
          autofill: [AutofillHints.email],
        ),
        _codeField(busy, _signupSentTo != null, () {
          final email = _email.text.trim();
          _act(() => controller.sendRegistrationCode(email), () {
            _signupSentTo = email;
            _startCooldown();
            _notice = '验证码已发送到 $email';
          });
        }),
        _field(
          _password,
          '密码',
          Icons.lock_outline,
          secret: true,
          autofill: [AutofillHints.newPassword],
        ),
        _field(_confirm, '确认密码', Icons.lock_outline, secret: true),
        ?message,
        _primary('注册', busy, () {
          if (!_matching()) return;
          _act(
            () => controller.register(
              _username.text.trim(),
              _email.text.trim(),
              _code.text.trim(),
              _password.text,
              _chooseImport,
            ),
            () {
              _clearSecrets();
              _signupSentTo = null;
            },
          );
        }),
      ] else ...[
        _field(
          _account,
          '用户名或邮箱',
          Icons.person_outline,
          autofill: [AutofillHints.username],
        ),
        _field(
          _password,
          '密码',
          Icons.lock_outline,
          secret: true,
          autofill: [AutofillHints.password],
        ),
        ?message,
        _primary(
          '登录',
          busy,
          () => _act(
            () => controller.login(
              _account.text.trim(),
              _password.text,
              _chooseImport,
            ),
            _clearSecrets,
          ),
        ),
        _link('忘记密码', busy ? null : () => _switch(_Mode.reset)),
      ],
    ];
  }

  List<Widget> _bindEmail(MainUser user, bool busy) {
    final controller = ref.read(mainAccountControllerProvider);
    final replacing = user.email != null;
    final message = _message();
    void send() {
      final email = _email.text.trim();
      _act(
        () => controller.sendEmailCode(
          email,
          currentPassword: replacing ? _password.text : null,
        ),
        () {
          _codeSentTo = email;
          _startCooldown();
          _notice = '验证码已发送到 $email，10 分钟内有效';
        },
      );
    }

    return [
      _title(replacing ? '更换邮箱' : '绑定邮箱'),
      if (!replacing)
        Text(
          '账号 ${user.username} 需要绑定邮箱，用于同步收藏和找回密码。',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      _field(
        _email,
        '邮箱',
        Icons.mail_outline,
        keyboard: TextInputType.emailAddress,
        autofill: [AutofillHints.email],
      ),
      if (replacing)
        _field(
          _password,
          '当前密码',
          Icons.lock_outline,
          secret: true,
          autofill: [AutofillHints.password],
        ),
      _codeField(busy, _codeSentTo != null, send),
      ?message,
      _primary(
        '完成绑定',
        busy,
        () => _act(
          () => controller.verifyEmail(_code.text.trim(), _chooseImport),
          () {
            _clearSecrets();
            _codeSentTo = null;
            _changingEmail = false;
            _notice = '邮箱已绑定';
          },
        ),
      ),
      if (!replacing) _link('退出登录', busy ? null : controller.logout),
    ];
  }

  List<Widget> _accountSummary(MainUser user, bool busy) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final controller = ref.read(mainAccountControllerProvider);
    final sync = ref.watch(collectionSyncProvider);
    final (icon, status) = sync == null
        ? (null, null)
        : sync.busy
        ? (Icons.sync, '正在同步收藏…')
        : sync.error != null
        ? (Icons.error_outline, sync.error)
        : sync.syncedAt == null
        ? (null, null)
        : sync.unknownCount > 0
        ? (Icons.cloud_queue, '${sync.unknownCount} 项收藏等待云端收录')
        : (Icons.cloud_done_outlined, '收藏已同步');
    final message = _changingEmail ? null : _message();
    return [
      Row(
        children: [
          AccountAvatar(name: user.username, size: 56),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  user.email!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      if (status != null)
        Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: sync?.error != null
                  ? colors.error
                  : colors.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                status,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: sync?.error != null
                      ? colors.error
                      : colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ?message,
      _primary('同步收藏', sync == null || sync.busy, () => sync?.sync()),
      Row(
        spacing: 10,
        children: [
          Expanded(
            child: AppButton(
              tonal: true,
              selected: _changingEmail,
              onPressed: busy
                  ? null
                  : () => setState(() {
                      _changingEmail = !_changingEmail;
                      _codeSentTo = null;
                      _notice = null;
                      _formError = null;
                    }),
              child: Text(_changingEmail ? '取消更换' : '更换邮箱'),
            ),
          ),
          Expanded(
            child: AppButton(
              tonal: true,
              onPressed: busy ? null : controller.logout,
              child: const Text('退出登录'),
            ),
          ),
        ],
      ),
    ];
  }
}
