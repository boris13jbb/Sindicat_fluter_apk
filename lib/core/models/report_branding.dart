/// Marca / logo para reportes PDF (Firestore `app_settings/branding`).
class ReportBranding {
  const ReportBranding({
    this.reportLogoUrl,
    this.updatedAt,
    this.updatedBy,
  });

  final String? reportLogoUrl;
  final int? updatedAt;
  final String? updatedBy;

  factory ReportBranding.fromMap(Map<String, dynamic> map) {
    final url = map['reportLogoUrl'] as String?;
    return ReportBranding(
      reportLogoUrl: (url != null && url.trim().isNotEmpty) ? url.trim() : null,
      updatedAt: (map['updatedAt'] as num?)?.toInt(),
      updatedBy: map['updatedBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'reportLogoUrl': reportLogoUrl ?? '',
      'updatedAt': updatedAt,
      'updatedBy': updatedBy,
    };
  }
}
