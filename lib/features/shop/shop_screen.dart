import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/feedback_service.dart';
import '../../core/services/payments/payment_service.dart';
import '../../core/utils/responsive.dart';
import '../../data/repositories/save_controller.dart';
import '../../game/models/creature_spec.dart';
import '../../game/models/power_up.dart';
import '../../widgets/buttons/pressable_scale.dart';
import '../../widgets/common/cozy_scaffold.dart';
import '../../widgets/creature/creature_view.dart';
import '../../widgets/scene/scene_background.dart';
import '../../widgets/score/bounce_on_change.dart';
import '../../widgets/score/stat_chip.dart';
import '../gameplay/widgets/power_up_bar.dart';
import 'model/cosmetics.dart';
import '../../core/services/ads/ad_service.dart';
import 'shop_controller.dart';

enum _Tab { coins, powerUps, cosmetics }

/// Shop: Coins (real money) · Power-ups (coins) · Cosmetics (coins), and a
/// Remove Ads bar (only in builds that show ads). Real-money items only appear purchasable when a store
/// is available; debug builds use a clearly-labelled test store.
class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  _Tab _tab = _Tab.powerUps;
  StoreProduct? _busy;

  ShopController get _shop => ref.read(shopControllerProvider);

  void _show(ShopOutcome o) {
    if (o.ok) ref.read(feedbackProvider).reward();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: o.ok ? AppColors.panel : const Color(0xFFFFE4E4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: o.ok ? AppColors.panelBorder : AppColors.danger,
              width: 2,
            ),
          ),
          content: Text(
            o.message,
            style: AppText.body(15, color: AppColors.woodDark),
          ),
        ),
      );
  }

  Future<void> _buyProduct(StoreProduct p) async {
    if (_busy != null) return;
    setState(() => _busy = p);
    final o = await _shop.buyProduct(p);
    if (!mounted) return;
    setState(() => _busy = null);
    _show(o);
  }

  @override
  Widget build(BuildContext context) {
    final coins = ref.watch(saveProvider.select((s) => s.coins));
    final payments = ref.watch(paymentServiceProvider);
    return CozyScaffold(
      title: 'Shop',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final r = Responsive.of(constraints.biggest);
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(r.s(16), r.s(4), r.s(16), r.s(24)),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: BounceOnChange(
                    value: coins,
                    child: StatChip(
                      icon: Icons.monetization_on_rounded,
                      iconColor: AppColors.sunshineDeep,
                      value: coins,
                      semanticLabel: 'Coins',
                      height: r.s(38),
                    ),
                  ),
                ),
                SizedBox(height: r.s(10)),
                _Awning(height: r.s(26)),
                Container(
                  padding: EdgeInsets.fromLTRB(
                    r.s(12),
                    r.s(12),
                    r.s(12),
                    r.s(14),
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.panel,
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(r.s(26)),
                    ),
                    border: Border.all(color: AppColors.panelBorder, width: 4),
                  ),
                  child: Column(
                    children: [
                      _Tabs(
                        current: _tab,
                        scale: r.scale,
                        onTap: (t) => setState(() => _tab = t),
                      ),
                      SizedBox(height: r.s(10)),
                      ...switch (_tab) {
                        _Tab.coins => _coinRows(r, payments),
                        _Tab.powerUps => _powerUpRows(r, coins),
                        _Tab.cosmetics => _cosmeticRows(r, coins),
                      },
                    ],
                  ),
                ),
                SizedBox(height: r.s(14)),
                // Only offered while the game can actually show ads: selling
                // "Remove Ads" in a build without ads would do nothing.
                if (ref.watch(adServiceProvider).interstitialAvailable ||
                    ref.watch(saveProvider.select((s) => s.adsRemoved)))
                  _removeAds(r, payments),
                if (payments.isTestStore) ...[
                  SizedBox(height: r.s(8)),
                  Text(
                    'Test store (debug build): no real money is charged.',
                    style: AppText.body(r.s(12), color: AppColors.softBrown),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  // --- Tabs ------------------------------------------------------------------

  List<Widget> _coinRows(Responsive r, PaymentService payments) {
    if (!payments.available) {
      return [
        Padding(
          padding: EdgeInsets.all(r.s(18)),
          child: Text(
            'Coin packs are coming soon!\nEarn coins by merging big puffs, '
            'daily challenges and your streak.',
            textAlign: TextAlign.center,
            style: AppText.body(r.s(15), color: AppColors.woodDark),
          ),
        ),
      ];
    }
    return [
      for (final pack in ShopCatalog.coinPacks)
        _ShopRow(
          scale: r.scale,
          leading: _CoinPile(count: pack.coins, size: r.s(48)),
          title: '${_fmt(pack.coins)} Coins',
          action: _PriceButton.money(
            label: _busy == pack.product
                ? '...'
                : (payments.priceOf(pack.product) ?? 'Buy'),
            scale: r.scale,
            onTap: () => _buyProduct(pack.product),
          ),
        ),
      SizedBox(height: r.s(6)),
      TextButton(
        onPressed: () async {
          final o = await _shop.restorePurchases();
          if (mounted) _show(o);
        },
        child: Text(
          'Restore purchases',
          style: AppText.body(r.s(14), color: AppColors.candyBlue),
        ),
      ),
    ];
  }

  List<Widget> _powerUpRows(Responsive r, int coins) => [
    for (final pack in ShopCatalog.powerUpPacks)
      _ShopRow(
        scale: r.scale,
        leading: PowerUpIcon(kind: pack.powerUp, size: r.s(48)),
        title: '${pack.powerUp.label} x${pack.amount}',
        subtitle: switch (pack.powerUp) {
          PowerUp.sweep => 'Clears the smallest puffs',
          PowerUp.pop => 'Removes one puff you pick',
          PowerUp.grow => 'Levels up one puff',
          PowerUp.shake => 'Shakes the jar loose',
        },
        action: _PriceButton.coins(
          price: pack.price,
          affordable: coins >= pack.price,
          scale: r.scale,
          onTap: () => _show(_shop.buyPowerUps(pack)),
        ),
      ),
  ];

  List<Widget> _cosmeticRows(Responsive r, int coins) {
    final save = ref.watch(saveProvider);
    final jar = ref.watch(equippedJarProvider);
    final scene = ref.watch(equippedSceneProvider);
    Widget actionFor(String id, int price, bool equipped) {
      final owned =
          Cosmetics.defaults.contains(id) || save.ownedCosmetics.contains(id);
      if (equipped) {
        return _PriceButton.label('Equipped', scale: r.scale, onTap: null);
      }
      if (owned) {
        return _PriceButton.label(
          'Equip',
          scale: r.scale,
          onTap: () => _show(_shop.buyOrEquip(id)),
        );
      }
      return _PriceButton.coins(
        price: price,
        affordable: coins >= price,
        scale: r.scale,
        onTap: () => _show(_shop.buyOrEquip(id)),
      );
    }

    return [
      _SectionLabel('Jars', scale: r.scale),
      for (final j in Cosmetics.jarSkins)
        _ShopRow(
          scale: r.scale,
          leading: _JarSwatch(skin: j, size: r.s(48)),
          title: j.name,
          action: actionFor(j.id, j.price, j.id == jar.id),
        ),
      SizedBox(height: r.s(6)),
      _SectionLabel('Backgrounds', scale: r.scale),
      for (final s in Cosmetics.scenes)
        _ShopRow(
          scale: r.scale,
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(r.s(12)),
            child: SizedBox.square(
              dimension: r.s(48),
              child: SceneBackground(theme: s),
            ),
          ),
          title: s.name,
          action: actionFor(s.id, s.price, s.id == scene.id),
        ),
    ];
  }

  Widget _removeAds(Responsive r, PaymentService payments) {
    final removed = ref.watch(saveProvider.select((s) => s.adsRemoved));
    final label = removed
        ? 'Ads removed'
        : (!payments.available
              ? 'Remove Ads: coming soon'
              : (_busy == StoreProduct.removeAds
                    ? 'Remove Ads ...'
                    : 'Remove Ads  ${payments.priceOf(StoreProduct.removeAds) ?? ''}'));
    final enabled = !removed && payments.available;
    return PressableScale(
      onTap: enabled ? () => _buyProduct(StoreProduct.removeAds) : null,
      semanticLabel: label,
      child: Container(
        height: r.s(56),
        padding: EdgeInsets.symmetric(horizontal: r.s(16)),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(r.s(28)),
          border: Border.all(color: AppColors.white, width: 3),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.candyPinkTop, AppColors.candyPink],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x55C72E6E),
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              removed ? Icons.check_circle_rounded : Icons.block_rounded,
              color: AppColors.white,
              size: r.s(24),
            ),
            SizedBox(width: r.s(8)),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: AppText.display(r.s(20), color: AppColors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _fmt(int n) => formatNumber(n);
}

// -----------------------------------------------------------------------------

class _Awning extends StatelessWidget {
  const _Awning({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size(double.infinity, height),
    painter: _AwningPainter(),
  );
}

class _AwningPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const stripes = 10;
    final w = size.width / stripes;
    final body = size.height * 0.62;
    final scallop = size.height - body;

    // One outline: rounded top band + a scalloped bottom edge.
    final shape = Path()
      ..moveTo(0, body)
      ..lineTo(0, 12)
      ..quadraticBezierTo(0, 0, 12, 0)
      ..lineTo(size.width - 12, 0)
      ..quadraticBezierTo(size.width, 0, size.width, 12)
      ..lineTo(size.width, body);
    for (var i = stripes - 1; i >= 0; i--) {
      final x0 = (i + 1) * w, x1 = i * w;
      shape.quadraticBezierTo((x0 + x1) / 2, body + scallop * 1.6, x1, body);
    }
    shape.close();

    canvas.save();
    canvas.clipPath(shape);
    final p = Paint();
    for (var i = 0; i < stripes; i++) {
      p.color = i.isEven ? AppColors.candyPink : AppColors.white;
      canvas.drawRect(Rect.fromLTWH(i * w, 0, w, size.height), p);
    }
    // Soft shading along the top for a fabric feel.
    p.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        AppColors.white.withValues(alpha: 0.35),
        AppColors.white.withValues(alpha: 0),
      ],
    ).createShader(Offset.zero & Size(size.width, body));
    canvas.drawRect(Offset.zero & Size(size.width, body), p);
    canvas.restore();

    canvas.drawPath(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..color = AppColors.candyPinkLip,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.current,
    required this.scale,
    required this.onTap,
  });

  final _Tab current;
  final double scale;
  final void Function(_Tab) onTap;

  static const _labels = {
    _Tab.coins: 'Coins',
    _Tab.powerUps: 'Power-ups',
    _Tab.cosmetics: 'Cosmetics',
  };

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return Container(
      padding: EdgeInsets.all(4 * s),
      decoration: BoxDecoration(
        color: AppColors.panelInset,
        borderRadius: BorderRadius.circular(20 * s),
      ),
      child: Row(
        children: [
          for (final t in _Tab.values)
            Expanded(
              child: Semantics(
                selected: t == current,
                child: PressableScale(
                  onTap: () => onTap(t),
                  semanticLabel: '${_labels[t]} tab',
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: EdgeInsets.symmetric(vertical: 8 * s),
                    decoration: BoxDecoration(
                      color: t == current
                          ? AppColors.white
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16 * s),
                      boxShadow: t == current ? AppShadowsSmall.soft : null,
                    ),
                    alignment: Alignment.center,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _labels[t]!,
                        style: AppText.display(
                          15 * s,
                          color: t == current
                              ? AppColors.woodDark
                              : AppColors.softBrown,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Local soft shadow (keeps the tab pill light).
abstract final class AppShadowsSmall {
  static const soft = [
    BoxShadow(color: Color(0x1A4A3F45), blurRadius: 6, offset: Offset(0, 2)),
  ];
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {required this.scale});
  final String text;
  final double scale;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: EdgeInsets.fromLTRB(6 * scale, 4 * scale, 0, 4 * scale),
      child: Text(
        text,
        style: AppText.display(16 * scale, color: AppColors.woodDark),
      ),
    ),
  );
}

class _ShopRow extends StatelessWidget {
  const _ShopRow({
    required this.scale,
    required this.leading,
    required this.title,
    required this.action,
    this.subtitle,
  });

  final double scale;
  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return Container(
      margin: EdgeInsets.only(bottom: 8 * s),
      padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 8 * s),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16 * s),
        border: Border.all(color: AppColors.panelBorder, width: 1.5),
      ),
      child: Row(
        children: [
          leading,
          SizedBox(width: 10 * s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.display(17 * s),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(12 * s, color: AppColors.softBrown),
                  ),
              ],
            ),
          ),
          SizedBox(width: 8 * s),
          action,
        ],
      ),
    );
  }
}

/// Price / action pill: blue for real money, yellow with a coin for coins,
/// cream for Equip/Equipped.
class _PriceButton extends StatelessWidget {
  const _PriceButton._({
    required this.label,
    required this.scale,
    required this.onTap,
    required this.colors,
    required this.textColor,
    this.coin = false,
    this.semantic,
  });

  factory _PriceButton.money({
    required String label,
    required double scale,
    required VoidCallback onTap,
  }) => _PriceButton._(
    label: label,
    scale: scale,
    onTap: onTap,
    colors: const [AppColors.candyBlueTop, AppColors.candyBlue],
    textColor: AppColors.white,
    semantic: 'Buy for $label',
  );

  factory _PriceButton.coins({
    required int price,
    required bool affordable,
    required double scale,
    required VoidCallback onTap,
  }) => _PriceButton._(
    label: formatNumber(price),
    scale: scale,
    onTap: onTap,
    colors: affordable
        ? const [AppColors.candyYellowTop, AppColors.candyYellow]
        : const [Color(0xFFEDE3D6), Color(0xFFDCCFBF)],
    textColor: AppColors.woodDark,
    coin: true,
    semantic: 'Buy for $price coins${affordable ? '' : ', not enough coins'}',
  );

  factory _PriceButton.label(
    String label, {
    required double scale,
    required VoidCallback? onTap,
  }) => _PriceButton._(
    label: label,
    scale: scale,
    onTap: onTap,
    colors: onTap == null
        ? const [Color(0xFFE6F6EA), Color(0xFFCDEBD5)]
        : const [AppColors.candyGreenTop, AppColors.candyGreen],
    textColor: onTap == null ? AppColors.candyGreenLip : AppColors.white,
  );

  final String label;
  final double scale;
  final VoidCallback? onTap;
  final List<Color> colors;
  final Color textColor;
  final bool coin;
  final String? semantic;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return PressableScale(
      onTap: onTap,
      dimWhenDisabled: false,
      semanticLabel: semantic ?? label,
      child: Container(
        constraints: BoxConstraints(minWidth: 84 * s),
        padding: EdgeInsets.symmetric(horizontal: 12 * s, vertical: 8 * s),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20 * s),
          border: Border.all(color: AppColors.white, width: 2),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (coin) ...[
              // Brown, like the text: a yellow coin vanishes on a yellow pill.
              Icon(
                Icons.monetization_on_rounded,
                color: textColor,
                size: 18 * s,
              ),
              SizedBox(width: 4 * s),
            ],
            Text(label, style: AppText.display(16 * s, color: textColor)),
          ],
        ),
      ),
    );
  }
}

class _CoinPile extends StatelessWidget {
  const _CoinPile({required this.count, required this.size});
  final int count;
  final double size;

  @override
  Widget build(BuildContext context) {
    final n = count >= 5000 ? 4 : (count >= 1500 ? 3 : 2);
    return SizedBox.square(
      dimension: size,
      child: Stack(
        children: [
          for (var i = 0; i < n; i++)
            Positioned(
              left: size * (0.05 + 0.18 * (i % 2)) + i * size * 0.06,
              top: size * (0.35 - 0.12 * i),
              child: Icon(
                Icons.monetization_on_rounded,
                color: AppColors.sunshineDeep,
                size: size * 0.6,
                shadows: const [
                  Shadow(color: Color(0x40975A2A), offset: Offset(0, 2)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _JarSwatch extends StatelessWidget {
  const _JarSwatch({required this.skin, required this.size});
  final JarSkin skin;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.22),
        border: Border.all(color: skin.rim, width: size * 0.08),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [skin.interiorTop, skin.interiorBottom],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22975A2A),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.bottomCenter,
      child: CreatureView(spec: CreatureCatalog.byLevel(2), size: size * 0.5),
    );
  }
}
