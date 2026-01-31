import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Mixin pour optimiser les états des pages
/// Fournit: debounce, optimistic UI, gestion du loading, haptic feedback
mixin OptimizedStateMixin<T extends StatefulWidget> on State<T> {
  bool _isProcessing = false;
  Timer? _debounceTimer;
  
  /// Vérifie si une action est en cours (évite les doubles clics)
  bool get isProcessing => _isProcessing;
  
  /// Exécute une action avec protection contre les doubles clics + haptic
  Future<void> safeAction(Future<void> Function() action, {
    VoidCallback? onStart,
    VoidCallback? onComplete,
    Function(dynamic)? onError,
    bool haptic = true,
  }) async {
    if (_isProcessing) return;
    
    _isProcessing = true;
    if (haptic) HapticFeedback.lightImpact();
    onStart?.call();
    
    try {
      await action();
      if (haptic) HapticFeedback.mediumImpact();
      onComplete?.call();
    } catch (e) {
      if (haptic) HapticFeedback.heavyImpact();
      onError?.call(e);
    } finally {
      if (mounted) {
        _isProcessing = false;
      }
    }
  }
  
  /// Exécute une action avec debounce (utile pour les recherches)
  void debounce(VoidCallback action, {Duration delay = const Duration(milliseconds: 300)}) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(delay, () {
      if (mounted) action();
    });
  }
  
  /// Optimistic UI: met à jour l'état immédiatement, puis confirme avec le serveur
  Future<void> optimisticUpdate<R>({
    required VoidCallback updateUI,
    required Future<R> Function() serverCall,
    required VoidCallback rollback,
    Function(R)? onSuccess,
    Function(dynamic)? onError,
    bool haptic = true,
  }) async {
    // Mise à jour immédiate de l'UI
    if (haptic) HapticFeedback.selectionClick();
    updateUI();
    
    try {
      final result = await serverCall();
      if (mounted) {
        if (haptic) HapticFeedback.mediumImpact();
        onSuccess?.call(result);
      }
    } catch (e) {
      // Rollback en cas d'erreur
      if (mounted) {
        if (haptic) HapticFeedback.heavyImpact();
        rollback();
        onError?.call(e);
      }
    }
  }
  
  /// Affiche un snackbar d'erreur
  void showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }
  
  /// Affiche un snackbar de succès
  void showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
  
  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

/// Extension pour les boutons avec protection anti-double clic
class SafeButton extends StatefulWidget {
  final Widget child;
  final Future<void> Function()? onPressed;
  final ButtonStyle? style;
  
  const SafeButton({
    required this.child,
    this.onPressed,
    this.style,
  });

  @override
  _SafeButtonState createState() => _SafeButtonState();
}

class _SafeButtonState extends State<SafeButton> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: widget.onPressed == null || _isLoading
          ? null
          : () async {
              setState(() => _isLoading = true);
              try {
                await widget.onPressed!();
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
      style: widget.style,
      child: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : widget.child,
    );
  }
}

/// Bouton avec feedback haptique et animation
class TapFeedbackButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final double borderRadius;
  
  const TapFeedbackButton({
    required this.child,
    this.onTap,
    this.backgroundColor,
    this.borderRadius = 12,
  });

  @override
  _TapFeedbackButtonState createState() => _TapFeedbackButtonState();
}

class _TapFeedbackButtonState extends State<TapFeedbackButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: BorderRadius.circular(widget.borderRadius),
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
