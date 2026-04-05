import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/auth_provider.dart';
import '../../providers/badges_provider.dart';
import '../../providers/entries_provider.dart';
import '../../providers/foods_provider.dart';
import '../../providers/log_history_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _supabase = Supabase.instance.client;
  final _picker = ImagePicker();

  String? _avatarUrl;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  // ── Load ──────────────────────────────────────────────────────────────────

  Future<void> _loadAvatar() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final row = await _supabase
          .from('profiles')
          .select('avatar_url')
          .eq('id', userId)
          .maybeSingle();
      if (mounted) {
        setState(() => _avatarUrl = row?['avatar_url'] as String?);
      }
    } catch (_) {}
  }

  // ── Upload ────────────────────────────────────────────────────────────────

  Future<void> _pickAndUpload(ImageSource source) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final XFile? file = await _picker.pickImage(
      source: source,
      imageQuality: 90,
    );
    if (file == null || !mounted) return;

    // Show crop/zoom screen — returns PNG bytes of the cropped circle
    final Uint8List? croppedBytes = await Navigator.push<Uint8List>(
      context,
      MaterialPageRoute(
        builder: (_) => _AvatarCropScreen(imageFile: file),
        fullscreenDialog: true,
      ),
    );
    if (croppedBytes == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      final storagePath = '$userId/avatar';
      await _supabase.storage.from('avatars').uploadBinary(
        storagePath,
        croppedBytes,
        fileOptions: const FileOptions(contentType: 'image/png', upsert: true),
      );

      final publicUrl =
          _supabase.storage.from('avatars').getPublicUrl(storagePath);

      await _supabase
          .from('profiles')
          .update({'avatar_url': publicUrl})
          .eq('id', userId);

      if (mounted) {
        setState(() => _avatarUrl =
            '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  // ── Remove ────────────────────────────────────────────────────────────────

  Future<void> _removeAvatar() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _uploading = true);
    try {
      await _supabase.storage.from('avatars').remove(['$userId/avatar']);
      await _supabase
          .from('profiles')
          .update({'avatar_url': null})
          .eq('id', userId);
      if (mounted) setState(() => _avatarUrl = null);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove photo: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  // ── Bottom sheet ──────────────────────────────────────────────────────────

  void _showAvatarSheet() {
    final cs = Theme.of(context).extension<AppColorScheme>()!;
    showModalBottomSheet(
      context: context,
      backgroundColor: cs.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: cs.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              _SheetOption(
                icon: Icons.camera_alt_outlined,
                label: 'Take Photo',
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUpload(ImageSource.camera);
                },
              ),
              _SheetOption(
                icon: Icons.photo_library_outlined,
                label: 'Choose from Gallery',
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUpload(ImageSource.gallery);
                },
              ),
              if (_avatarUrl != null) ...[
                const Divider(indent: 16, endIndent: 16),
                _SheetOption(
                  icon: Icons.delete_outline,
                  label: 'Remove Photo',
                  color: AppColors.danger,
                  onTap: () {
                    Navigator.pop(ctx);
                    _removeAvatar();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);
    final user = ref.watch(currentUserProvider);

    final displayName = user?.userMetadata?['display_username'] as String? ??
        user?.email?.split('@').first ??
        'User';
    final email = user?.email ?? '';
    final initial = displayName.substring(0, 1).toUpperCase();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          // ── Avatar + name ────────────────────────────────────────────────
          Center(
            child: Column(
              children: [
                GestureDetector(
                  onTap: _uploading ? null : _showAvatarSheet,
                  child: Stack(
                    children: [
                      // Avatar circle
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.protein.withValues(alpha: 0.15),
                          border: Border.all(
                            color: AppColors.protein.withValues(alpha: 0.4),
                            width: 2,
                          ),
                        ),
                        child: ClipOval(
                          child: _uploading
                              ? const Center(
                                  child: SizedBox(
                                    width: 28,
                                    height: 28,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: AppColors.protein,
                                    ),
                                  ),
                                )
                              : _avatarUrl != null
                                  ? Image.network(
                                      _avatarUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          _initialsWidget(initial),
                                    )
                                  : _initialsWidget(initial),
                        ),
                      ),
                      // Camera badge
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: AppColors.protein,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: cs.bg,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            size: 13,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  displayName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: cs.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  email,
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.textMuted,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // ── Category nav rows ─────────────────────────────────────────────
          _CategoryCard(
            rows: [
              _CategoryRow(
                icon: Icons.settings_outlined,
                iconColor: cs.textMuted,
                iconBg: cs.border,
                title: 'General',
                subtitle: 'Account, appearance & language',
                onTap: () => context.push('/profile/general'),
              ),
              _CategoryRow(
                icon: Icons.track_changes_rounded,
                iconColor: AppColors.protein,
                iconBg: AppColors.protein.withValues(alpha: 0.12),
                title: 'Daily Goals',
                subtitle: 'Goal mode & macro targets',
                onTap: () => context.push('/profile/goals'),
              ),
              _CategoryRow(
                icon: Icons.monitor_weight_outlined,
                iconColor: AppColors.carbs,
                iconBg: AppColors.carbs.withValues(alpha: 0.12),
                title: 'Body Stats',
                subtitle: 'Age, weight, height & activity',
                onTap: () => context.push('/profile/stats'),
              ),
              _CategoryRow(
                icon: Icons.emoji_events_outlined,
                iconColor: const Color(0xFFFBBF24),
                iconBg: const Color(0xFFFBBF24).withValues(alpha: 0.12),
                title: 'Achievements',
                subtitle: 'Badges & milestones',
                onTap: () => context.push('/badges'),
                isLast: true,
              ),
            ],
          ),

          const SizedBox(height: 28),

          // ── Sign out ──────────────────────────────────────────────────────
          OutlinedButton.icon(
            onPressed: () => _confirmSignOut(context),
            icon: const Icon(Icons.logout, color: AppColors.danger),
            label: const Text(
              'Sign Out',
              style: TextStyle(color: AppColors.danger),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.danger),
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _initialsWidget(String initial) => Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w700,
            color: AppColors.protein,
          ),
        ),
      );

  Future<void> _confirmSignOut(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Sign Out',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(settingsProvider.notifier).clearLocalCache();
      // Invalidate all user-scoped data so the next sign-in starts clean.
      ref.invalidate(foodsProvider);
      ref.invalidate(entriesProvider);
      ref.invalidate(loggedDatesProvider);
      ref.invalidate(badgesProvider);
      await signOut();
    }
  }
}

// ── Bottom sheet option row ────────────────────────────────────────────────────

class _SheetOption extends StatelessWidget {
  const _SheetOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColorScheme.of(context).textPrimary;
    return ListTile(
      leading: Icon(icon, color: c),
      title: Text(label, style: TextStyle(color: c, fontWeight: FontWeight.w500)),
      onTap: onTap,
    );
  }
}

// ── Category card container ────────────────────────────────────────────────────

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.rows});
  final List<_CategoryRow> rows;

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: cs.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.border),
      ),
      child: Column(children: rows),
    );
  }
}

// ── Avatar crop / zoom screen ─────────────────────────────────────────────────

class _AvatarCropScreen extends StatefulWidget {
  const _AvatarCropScreen({required this.imageFile});
  final XFile imageFile;

  @override
  State<_AvatarCropScreen> createState() => _AvatarCropScreenState();
}

class _AvatarCropScreenState extends State<_AvatarCropScreen> {
  static const double _cropDiameter = 280.0;

  ui.Image? _image;
  double _scale = 1.0;
  double _minScale = 1.0;
  Offset _offset = Offset.zero;

  // Gesture tracking
  double _gestureStartScale = 1.0;
  Offset _gestureStartOffset = Offset.zero;
  Offset _gestureStartFocal = Offset.zero;

  final _cropKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final bytes = await widget.imageFile.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final img = frame.image;

    // Scale to fill the crop circle (cover fit)
    final minS = math.max(
      _cropDiameter / img.width,
      _cropDiameter / img.height,
    );

    if (mounted) {
      setState(() {
        _image = img;
        _scale = minS;
        _minScale = minS;
        _offset = Offset.zero;
      });
    }
  }

  void _onScaleStart(ScaleStartDetails d) {
    _gestureStartScale = _scale;
    _gestureStartOffset = _offset;
    _gestureStartFocal = d.focalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final newScale =
        (_gestureStartScale * d.scale).clamp(_minScale, _minScale * 6);
    final translation = d.focalPoint - _gestureStartFocal;
    setState(() {
      _scale = newScale;
      _offset = _clampOffset(_gestureStartOffset + translation, newScale);
    });
  }

  Offset _clampOffset(Offset o, double scale) {
    if (_image == null) return Offset.zero;
    final maxDx = math.max(0.0, (_image!.width * scale - _cropDiameter) / 2);
    final maxDy = math.max(0.0, (_image!.height * scale - _cropDiameter) / 2);
    return Offset(
      o.dx.clamp(-maxDx, maxDx),
      o.dy.clamp(-maxDy, maxDy),
    );
  }

  Future<void> _confirm() async {
    final boundary =
        _cropKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;
    // Render at 2× for a 560×560 PNG
    final img = await boundary.toImage(pixelRatio: 2.0);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    if (!mounted) return;
    Navigator.pop(context, data?.buffer.asUint8List());
  }

  @override
  Widget build(BuildContext context) {
    const r = _cropDiameter / 2;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Crop area (captured by RepaintBoundary) ─────────────────────
          Center(
            child: RepaintBoundary(
              key: _cropKey,
              child: SizedBox(
                width: _cropDiameter,
                height: _cropDiameter,
                child: ClipRect(
                  child: CustomPaint(
                    painter: _CropImagePainter(
                      image: _image,
                      offset: _offset,
                      scale: _scale,
                      cropSize: _cropDiameter,
                    ),
                    size: const Size(_cropDiameter, _cropDiameter),
                  ),
                ),
              ),
            ),
          ),

          // ── Dark scrim with circular window ─────────────────────────────
          IgnorePointer(
            child: CustomPaint(
              painter: _CropScrimPainter(cropRadius: r),
            ),
          ),

          // ── Circle border ────────────────────────────────────────────────
          IgnorePointer(
            child: Center(
              child: Container(
                width: _cropDiameter,
                height: _cropDiameter,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ),

          // ── Full-screen gesture layer (below buttons) ────────────────────
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: _onScaleStart,
            onScaleUpdate: _onScaleUpdate,
            child: const SizedBox.expand(),
          ),

          // ── Cancel (top-left) ────────────────────────────────────────────
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),

          // ── Bottom hint + Use Photo button ────────────────────────────────
          if (_image != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 36),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Pinch to zoom  •  Drag to reposition',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: 200,
                        child: ElevatedButton(
                          onPressed: _confirm,
                          style: ElevatedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          child: const Text('Use Photo'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}

class _CropImagePainter extends CustomPainter {
  const _CropImagePainter({
    required this.image,
    required this.offset,
    required this.scale,
    required this.cropSize,
  });

  final ui.Image? image;
  final Offset offset;
  final double scale;
  final double cropSize;

  @override
  void paint(Canvas canvas, Size size) {
    if (image == null) return;
    final imgW = image!.width * scale;
    final imgH = image!.height * scale;
    final dx = (cropSize - imgW) / 2 + offset.dx;
    final dy = (cropSize - imgH) / 2 + offset.dy;
    canvas.drawImageRect(
      image!,
      Rect.fromLTWH(0, 0, image!.width.toDouble(), image!.height.toDouble()),
      Rect.fromLTWH(dx, dy, imgW, imgH),
      Paint(),
    );
  }

  @override
  bool shouldRepaint(_CropImagePainter old) =>
      old.image != image || old.offset != offset || old.scale != scale;
}

class _CropScrimPainter extends CustomPainter {
  const _CropScrimPainter({required this.cropRadius});
  final double cropRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(Rect.fromCircle(center: center, radius: cropRadius))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(
      path,
      Paint()..color = Colors.black.withValues(alpha: 0.6),
    );
  }

  @override
  bool shouldRepaint(_CropScrimPainter old) => old.cropRadius != cropRadius;
}

// ── Single nav row ─────────────────────────────────────────────────────────────

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isLast = false,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.vertical(
            bottom: isLast ? const Radius.circular(16) : Radius.zero,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, color: iconColor, size: 21),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColorScheme.of(context).textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColorScheme.of(context).textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColorScheme.of(context).textMuted,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
        if (!isLast) const Divider(height: 1, indent: 72),
      ],
    );
  }
}
