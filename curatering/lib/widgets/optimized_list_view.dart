import 'package:flutter/material.dart';

/// Optimized ListView with lazy loading and recycling
class OptimizedListView<T> extends StatelessWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final int pageSize;
  final VoidCallback? onLoadMore;
  final bool isLoadingMore;
  final Widget? loadingWidget;
  final EdgeInsets padding;

  const OptimizedListView({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.pageSize = 20,
    this.onLoadMore,
    this.isLoadingMore = false,
    this.loadingWidget,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      cacheExtent: 200.0, padding: padding,
      itemCount: items.length + (isLoadingMore ? 1 : 0), // Increase cache for smoother scrolling
      addAutomaticKeepAlives: false, // Disable keep-alive for better memory usage
      addRepaintBoundaries: true, // Add repaint boundaries
      itemBuilder: (context, index) {
        // Load more trigger
        if (index == items.length - 5 && onLoadMore != null && !isLoadingMore) {
          onLoadMore!();
        }

        // Loading indicator at bottom
        if (index >= items.length) {
          return loadingWidget ??
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              );
        }

        // Wrap item in RepaintBoundary for isolation
        return RepaintBoundary(
          child: itemBuilder(context, items[index], index),
        );
      },
    );
  }
}

/// Grid version with similar optimizations
class OptimizedGridView<T> extends StatelessWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final int crossAxisCount;
  final double childAspectRatio;
  final int pageSize;
  final VoidCallback? onLoadMore;
  final bool isLoadingMore;
  final EdgeInsets padding;

  const OptimizedGridView({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.crossAxisCount = 2,
    this.childAspectRatio = 1.0,
    this.pageSize = 20,
    this.onLoadMore,
    this.isLoadingMore = false,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      cacheExtent: 200.0, padding: padding,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: items.length + (isLoadingMore ? 1 : 0),
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: true,
      itemBuilder: (context, index) {
        if (index == items.length - 5 && onLoadMore != null && !isLoadingMore) {
          onLoadMore!();
        }

        if (index >= items.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        return RepaintBoundary(
          child: itemBuilder(context, items[index], index),
        );
      },
    );
  }
}

/// Skeleton loading placeholder for better perceived performance
class SkeletonLoader extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius borderRadius;

  const SkeletonLoader({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: borderRadius,
      ),
      child: const SkeletonShimmer(),
    );
  }
}

/// Shimmer effect for skeleton loaders
class SkeletonShimmer extends StatefulWidget {
  const SkeletonShimmer({super.key});

  @override
  State<SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<SkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.grey.shade200,
                Colors.grey.shade300,
                Colors.grey.shade200,
              ],
              stops: [
                0.0,
                _controller.value,
                1.0,
              ],
            ),
          ),
        );
      },
    );
  }
}
