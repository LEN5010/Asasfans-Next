import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../shared/widgets/app_controls.dart';
import '../../../shared/widgets/app_page_bar.dart';
import '../../../shared/widgets/member_tone.dart';
import '../application/main_account_providers.dart';
import '../domain/main_account.dart';

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
  bool _resetSent = false;
  bool _changingEmail = false;
  String? _notice;
  String? _formError;

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

  bool _matching() {
    if (_password.text == _confirm.text) return true;
    setState(() => _formError = '两次输入的密码不一致');
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(mainAccountControllerProvider);
    final session = account.session;
    final error = _formError ?? account.error;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const AppPageBar(title: Text('用户')),
      body: Builder(
        builder: (context) => Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: AutofillGroup(
              child: ListView(
                padding: pageInsets(context, top: 4),
                children: [
                  if (account.loading)
                    const Center(child: CircularProgressIndicator())
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
                  if (account.busy)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                  if (error != null) _message(error, isError: true),
                  if (_notice != null) _message(_notice!),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(List<Widget> children) => AppCard(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < children.length; index++) ...[
          if (index > 0) const SizedBox(height: 12),
          children[index],
        ],
      ],
    ),
  );

  Widget _message(String text, {bool isError = false}) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Text(
      text,
      style: TextStyle(
        color: isError ? Theme.of(context).colorScheme.error : null,
      ),
    ),
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    bool secret = false,
    TextInputType? keyboard,
    Iterable<String>? autofill,
    int? maxLength,
  }) => TextField(
    controller: controller,
    obscureText: secret,
    keyboardType: keyboard,
    autofillHints: autofill,
    maxLength: maxLength,
    inputFormatters: keyboard == TextInputType.number
        ? [FilteringTextInputFormatter.digitsOnly]
        : null,
    decoration: InputDecoration(labelText: label, counterText: ''),
  );

  Widget _primary(String label, VoidCallback? onPressed) => Align(
    alignment: Alignment.centerLeft,
    child: AppButton(selected: true, onPressed: onPressed, child: Text(label)),
  );

  List<Widget> _signIn(bool busy) {
    final controller = ref.read(mainAccountControllerProvider);
    if (_mode == _Mode.reset) {
      return [
        Text('重设密码', style: Theme.of(context).textTheme.titleMedium),
        _field(_account, '用户名或邮箱', autofill: [AutofillHints.username]),
        if (!_resetSent)
          _primary(
            '发送验证码',
            busy
                ? null
                : () => _act(
                    () => controller.requestPasswordReset(_account.text.trim()),
                    () {
                      _resetSent = true;
                      _notice = '如果该账号已绑定邮箱，验证码已发送到邮箱';
                    },
                  ),
          )
        else ...[
          _field(_code, '验证码', keyboard: TextInputType.number, maxLength: 6),
          _field(
            _password,
            '新密码',
            secret: true,
            autofill: [AutofillHints.newPassword],
          ),
          _field(_confirm, '确认新密码', secret: true),
          _primary(
            '重设密码',
            busy
                ? null
                : () {
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
                  },
          ),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: AppButton(
            onPressed: () => setState(() {
              _mode = _Mode.login;
              _resetSent = false;
              _notice = null;
              _formError = null;
            }),
            child: const Text('返回登录'),
          ),
        ),
      ];
    }
    final register = _mode == _Mode.register;
    return [
      AppSegments<_Mode>(
        values: const [_Mode.login, _Mode.register],
        labelOf: (mode) => mode == _Mode.login ? '登录' : '注册',
        selected: _mode,
        onChanged: busy
            ? null
            : (mode) => setState(() {
                _mode = mode;
                _formError = null;
              }),
      ),
      if (register) ...[
        _field(_username, '用户名', autofill: [AutofillHints.newUsername]),
        _field(
          _email,
          '邮箱',
          keyboard: TextInputType.emailAddress,
          autofill: [AutofillHints.email],
        ),
        _field(
          _password,
          '密码',
          secret: true,
          autofill: [AutofillHints.newPassword],
        ),
        _field(_confirm, '确认密码', secret: true),
        _primary(
          '注册',
          busy
              ? null
              : () {
                  if (!_matching()) return;
                  final email = _email.text.trim();
                  _act(
                    () => controller.register(
                      _username.text.trim(),
                      email,
                      _password.text,
                    ),
                    () {
                      _clearSecrets();
                      _codeSentTo = email;
                    },
                  );
                },
        ),
      ] else ...[
        _field(_account, '用户名或邮箱', autofill: [AutofillHints.username]),
        _field(
          _password,
          '密码',
          secret: true,
          autofill: [AutofillHints.password],
        ),
        Wrap(
          spacing: 8,
          children: [
            AppButton(
              selected: true,
              onPressed: busy
                  ? null
                  : () => _act(
                      () => controller.login(
                        _account.text.trim(),
                        _password.text,
                        _chooseImport,
                      ),
                      _clearSecrets,
                    ),
              child: const Text('登录'),
            ),
            AppButton(
              onPressed: busy
                  ? null
                  : () => setState(() {
                      _mode = _Mode.reset;
                      _formError = null;
                    }),
              child: const Text('忘记密码'),
            ),
          ],
        ),
      ],
    ];
  }

  List<Widget> _bindEmail(MainUser user, bool busy) {
    final controller = ref.read(mainAccountControllerProvider);
    final replacing = user.email != null;
    void send(String email) => _act(
      () => controller.sendEmailCode(
        email,
        currentPassword: replacing ? _password.text : null,
      ),
      () {
        _codeSentTo = email;
        _notice = '验证码已发送';
      },
    );
    return [
      Text(
        replacing ? '更换邮箱' : '绑定邮箱',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      if (!replacing) Text('账号 ${user.username} 需要绑定邮箱，用于找回密码。'),
      if (_codeSentTo == null) ...[
        _field(
          _email,
          '邮箱',
          keyboard: TextInputType.emailAddress,
          autofill: [AutofillHints.email],
        ),
        if (replacing)
          _field(
            _password,
            '当前密码',
            secret: true,
            autofill: [AutofillHints.password],
          ),
        _primary('发送验证码', busy ? null : () => send(_email.text.trim())),
      ] else ...[
        Text('验证码已发送到 $_codeSentTo，10 分钟内有效。'),
        _field(_code, '验证码', keyboard: TextInputType.number, maxLength: 6),
        Wrap(
          spacing: 8,
          children: [
            AppButton(
              selected: true,
              onPressed: busy
                  ? null
                  : () => _act(
                      () => controller.verifyEmail(
                        _code.text.trim(),
                        _chooseImport,
                      ),
                      () {
                        _clearSecrets();
                        _codeSentTo = null;
                        _changingEmail = false;
                        _notice = '邮箱已绑定';
                      },
                    ),
              child: const Text('完成绑定'),
            ),
            AppButton(
              onPressed: busy ? null : () => send(_codeSentTo!),
              child: const Text('重新发送'),
            ),
            AppButton(
              onPressed: busy
                  ? null
                  : () => setState(() {
                      _codeSentTo = null;
                      _notice = null;
                    }),
              child: const Text('换一个邮箱'),
            ),
          ],
        ),
      ],
      if (!replacing)
        Align(
          alignment: Alignment.centerLeft,
          child: AppButton(
            onPressed: busy ? null : controller.logout,
            child: const Text('退出登录'),
          ),
        ),
    ];
  }

  List<Widget> _accountSummary(MainUser user, bool busy) {
    final theme = Theme.of(context);
    final controller = ref.read(mainAccountControllerProvider);
    final sync = ref.watch(collectionSyncProvider);
    final status = sync == null
        ? null
        : sync.busy
        ? '正在同步收藏…'
        : sync.error ??
              (sync.syncedAt == null
                  ? null
                  : sync.unknownCount > 0
                  ? '${sync.unknownCount} 项收藏等待云端收录'
                  : '收藏已同步');
    return [
      Row(
        children: [
          const ToneBadge(icon: Icons.person_outline, member: '嘉然'),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.username, style: theme.textTheme.titleMedium),
                Text(
                  user.email!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      if (status != null)
        Text(
          status,
          style: theme.textTheme.bodySmall?.copyWith(
            color: sync?.error != null ? theme.colorScheme.error : null,
          ),
        ),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          AppButton.withIcon(
            icon: const Icon(Icons.sync),
            label: const Text('同步收藏'),
            selected: true,
            onPressed: sync == null || sync.busy ? null : sync.sync,
          ),
          AppButton(
            onPressed: busy
                ? null
                : () => setState(() {
                    _changingEmail = !_changingEmail;
                    _codeSentTo = null;
                  }),
            child: Text(_changingEmail ? '取消更换邮箱' : '更换邮箱'),
          ),
          AppButton(
            onPressed: busy ? null : controller.logout,
            child: const Text('退出登录'),
          ),
        ],
      ),
    ];
  }
}
