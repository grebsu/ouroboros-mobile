class LoadingState {
  final String currentStatus;
  final double progress;
  final int currentSubjects;
  final int totalSubjects;
  final int currentTopics;
  final int totalTopics;

  LoadingState({
    required this.currentStatus,
    required this.progress,
    this.currentSubjects = 0,
    this.totalSubjects = 0,
    this.currentTopics = 0,
    this.totalTopics = 0,
  });

  LoadingState copyWith({
    String? currentStatus,
    double? progress,
    int? currentSubjects,
    int? totalSubjects,
    int? currentTopics,
    int? totalTopics,
  }) {
    return LoadingState(
      currentStatus: currentStatus ?? this.currentStatus,
      progress: progress ?? this.progress,
      currentSubjects: currentSubjects ?? this.currentSubjects,
      totalSubjects: totalSubjects ?? this.totalSubjects,
      currentTopics: currentTopics ?? this.currentTopics,
      totalTopics: totalTopics ?? this.totalTopics,
    );
  }
}