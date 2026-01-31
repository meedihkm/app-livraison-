import 'package:flutter/material.dart';

/// Widget de skeleton loading pour améliorer la perception de vitesse
class SkeletonLoader extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  
  const SkeletonLoader({
    this.width = double.infinity,
    this.height = 20,
    this.borderRadius = 8,
  });

  @override
  _SkeletonLoaderState createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(_animation.value - 1, 0),
              end: Alignment(_animation.value, 0),
              colors: [
                Colors.grey[300]!,
                Colors.grey[100]!,
                Colors.grey[300]!,
              ],
            ),
          ),
        );
      },
    );
  }
}


/// Skeleton pour une carte de commande
class OrderCardSkeleton extends StatelessWidget {
  const OrderCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SkeletonLoader(width: 48, height: 48, borderRadius: 12),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      SkeletonLoader(width: 120, height: 16),
                      SizedBox(height: 6),
                      SkeletonLoader(width: 80, height: 12),
                    ],
                  ),
                ),
                const SkeletonLoader(width: 70, height: 28, borderRadius: 14),
              ],
            ),
            const SizedBox(height: 16),
            const SkeletonLoader(height: 14),
            const SizedBox(height: 8),
            const SkeletonLoader(width: 150, height: 14),
          ],
        ),
      ),
    );
  }
}

/// Skeleton pour une carte de produit
class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: const Center(child: SkeletonLoader(width: 60, height: 60, borderRadius: 12)),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  SkeletonLoader(height: 14),
                  SizedBox(height: 8),
                  SkeletonLoader(width: 60, height: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton pour une carte de livraison
class DeliveryCardSkeleton extends StatelessWidget {
  const DeliveryCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const SkeletonLoader(width: 44, height: 44, borderRadius: 12),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      SkeletonLoader(width: 100, height: 16),
                      SizedBox(height: 6),
                      SkeletonLoader(width: 80, height: 12),
                    ],
                  ),
                ),
                const SkeletonLoader(width: 70, height: 28, borderRadius: 14),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: const [
                SkeletonLoader(height: 14),
                SizedBox(height: 8),
                SkeletonLoader(height: 14),
                SizedBox(height: 12),
                SkeletonLoader(width: 120, height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Liste de skeletons
class SkeletonList extends StatelessWidget {
  final int count;
  final Widget Function() itemBuilder;
  
  const SkeletonList({
    this.count = 5,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      itemBuilder: (_, __) => itemBuilder(),
    );
  }
}

/// Grille de skeletons pour les produits
class SkeletonGrid extends StatelessWidget {
  final int count;
  
  const SkeletonGrid({this.count = 6});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: count,
      itemBuilder: (_, __) => const ProductCardSkeleton(),
    );
  }
}
