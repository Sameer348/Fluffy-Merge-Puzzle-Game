import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_info.dart';
import '../../core/utils/responsive.dart';
import '../../data/local/save_data.dart';
import '../../data/repositories/save_controller.dart';
import '../../widgets/buttons/pressable_scale.dart';
import '../../widgets/buttons/soft_button.dart';
import '../../widgets/common/cozy_scaffold.dart';
import '../../widgets/common/wood_sign.dart';

/// Settings: sound and feel toggles (saved instantly, applied live),
/// volume sliders, language, privacy policy, about, and Back.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(saveProvider.select((d) => d.settings));
    void update(GameSettings Function(GameSettings) f) =>
        ref.read(saveProvider.notifier).updateSettings(f);

    return CozyScaffold(
      title: 'Settings',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final r = Responsive.of(constraints.biggest);
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(r.s(18), r.s(8), r.s(18), r.s(24)),
            child: Column(
              children: [
                _Panel(
                  scale: r.scale,
                  children: [
                    _ToggleRow(
                      icon: Icons.music_note_rounded,
                      color: AppColors.candyBlue,
                      label: 'Music',
                      value: s.music,
                      scale: r.scale,
                      onChanged: (v) => update((x) => x.copyWith(music: v)),
                    ),
                    if (s.music)
                      _VolumeRow(
                        label: 'Music volume',
                        value: s.musicVolume,
                        scale: r.scale,
                        onChanged: (v) =>
                            update((x) => x.copyWith(musicVolume: v)),
                      ),
                    _ToggleRow(
                      icon: Icons.volume_up_rounded,
                      color: AppColors.candyBlue,
                      label: 'Sound Effects',
                      value: s.sfx,
                      scale: r.scale,
                      onChanged: (v) => update((x) => x.copyWith(sfx: v)),
                    ),
                    if (s.sfx)
                      _VolumeRow(
                        label: 'Sound effects volume',
                        value: s.sfxVolume,
                        scale: r.scale,
                        onChanged: (v) =>
                            update((x) => x.copyWith(sfxVolume: v)),
                      ),
                    _ToggleRow(
                      icon: Icons.vibration_rounded,
                      color: AppColors.candyBlue,
                      label: 'Haptics',
                      value: s.haptics,
                      scale: r.scale,
                      onChanged: (v) => update((x) => x.copyWith(haptics: v)),
                    ),
                    _ToggleRow(
                      icon: Icons.auto_awesome_motion_rounded,
                      color: AppColors.candyPurple,
                      label: 'Reduced Animations',
                      value: s.reducedMotion,
                      scale: r.scale,
                      onChanged: (v) =>
                          update((x) => x.copyWith(reducedMotion: v)),
                    ),
                  ],
                ),
                SizedBox(height: r.s(14)),
                _Panel(
                  scale: r.scale,
                  children: [
                    _LinkRow(
                      icon: Icons.language_rounded,
                      label: 'Language',
                      trailing: 'English',
                      scale: r.scale,
                      onTap: null,
                    ),
                    _LinkRow(
                      icon: Icons.privacy_tip_rounded,
                      label: 'Privacy Policy',
                      scale: r.scale,
                      onTap: () => _info(
                        context,
                        title: 'Privacy',
                        body:
                            '${AppInfo.name} keeps your progress on this '
                            'device only. There are no accounts, and your '
                            'game data is never sent to us or anyone else.'
                            '\n\nThe app downloads nothing and collects no '
                            'analytics. Purchases, if you make any, are '
                            'handled by Google Play or the App Store.'
                            '\n\nIf ads are added in a future update, this '
                            'policy will be updated first.',
                      ),
                    ),
                    _LinkRow(
                      icon: Icons.info_rounded,
                      label: 'About',
                      scale: r.scale,
                      onTap: () => _info(
                        context,
                        title: AppInfo.name,
                        body:
                            'Version ${AppInfo.version}\n\nA cozy merge '
                            'puzzle about very fluffy friends.\n\nEvery '
                            'creature, picture and sound in this game is '
                            'created in code just for it. Fonts: Fredoka '
                            'and Nunito (SIL Open Font License).',
                      ),
                    ),
                    _LinkRow(
                      icon: Icons.description_rounded,
                      label: 'Licenses',
                      scale: r.scale,
                      onTap: () => showLicensePage(
                        context: context,
                        applicationName: AppInfo.name,
                        applicationVersion: AppInfo.version,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: r.s(18)),
                SoftButton(
                  label: 'Back',
                  candy: CandyColor.pink,
                  height: r.s(56),
                  fontSize: r.s(22),
                  onTap: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static Future<void> _info(
    BuildContext context, {
    required String title,
    required String body,
  }) => showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: const Color(0x664A3F45),
    pageBuilder: (context, _, _) => Center(
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Material(
            type: MaterialType.transparency,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 24),
                  padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
                  decoration: BoxDecoration(
                    color: AppColors.panel,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: AppColors.panelBorder, width: 4),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        body,
                        textAlign: TextAlign.center,
                        style: AppText.body(15, color: AppColors.woodDark),
                      ),
                      const SizedBox(height: 16),
                      SoftButton(
                        label: 'Close',
                        candy: CandyColor.blue,
                        height: 48,
                        fontSize: 18,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                WoodSign(text: title, fontSize: 22),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.children, required this.scale});
  final List<Widget> children;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 12 * scale,
        vertical: 8 * scale,
      ),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(24 * scale),
        border: Border.all(color: AppColors.panelBorder, width: 4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33975A2A),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _IconBubble extends StatelessWidget {
  const _IconBubble(this.icon, this.color, this.size);
  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color.withValues(alpha: 0.16),
    ),
    child: Icon(icon, color: color, size: size * 0.6),
  );
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.scale,
    required this.onChanged,
  });

  final IconData icon;
  final Color color;
  final String label;
  final bool value;
  final double scale;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    // The whole row toggles (bigger target than the switch alone).
    return MergeSemantics(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 4 * s),
          child: Row(
            children: [
              _IconBubble(icon, color, 36 * s),
              SizedBox(width: 12 * s),
              Expanded(
                child: Text(
                  label,
                  style: AppText.display(17 * s, color: AppColors.woodDark),
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeTrackColor: AppColors.candyGreen,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VolumeRow extends StatelessWidget {
  const _VolumeRow({
    required this.label,
    required this.value,
    required this.scale,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double scale;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 40 * scale),
      child: Row(
        children: [
          Icon(
            Icons.volume_down_rounded,
            color: AppColors.softBrown,
            size: 18 * scale,
          ),
          Expanded(
            child: Slider(
              value: value,
              onChanged: onChanged,
              label: '${(value * 100).round()}%',
              semanticFormatterCallback: (v) => '$label ${(v * 100).round()}%',
            ),
          ),
          Icon(
            Icons.volume_up_rounded,
            color: AppColors.softBrown,
            size: 18 * scale,
          ),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.label,
    required this.scale,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String? trailing;
  final double scale;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final row = Padding(
      padding: EdgeInsets.symmetric(vertical: 8 * s),
      child: Row(
        children: [
          _IconBubble(icon, AppColors.candyBlue, 36 * s),
          SizedBox(width: 12 * s),
          Expanded(
            child: Text(
              label,
              style: AppText.display(17 * s, color: AppColors.woodDark),
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: AppText.body(15 * s, color: AppColors.softBrown),
            ),
          if (onTap != null)
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.softBrown,
              size: 26 * s,
            ),
        ],
      ),
    );
    if (onTap == null) {
      return Semantics(
        label: trailing == null ? label : '$label: $trailing',
        excludeSemantics: true,
        child: row,
      );
    }
    return PressableScale(
      onTap: onTap,
      pressedScale: 0.98,
      semanticLabel: label,
      child: row,
    );
  }
}
