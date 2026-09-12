// lib/widgets/story_links_section.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

class RealStoryLink {
  final String title;
  final String channel;
  final String url;
  final String videoId;
  const RealStoryLink({
    required this.title,
    required this.channel,
    required this.url,
    required this.videoId,
  });

  String get thumbnailUrl => 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
}

const _realStories = <RealStoryLink>[
  RealStoryLink(
    title: 'नेता मंत्री की पहचान बता नौकरी लगाने के नाम पर ठगी',
    channel: 'Thiha Chhattisgarh',
    url: 'https://youtube.com/shorts/TXDbjtwSdMM?si=uepV4R5XP6cKzUr_',
    videoId: 'TXDbjtwSdMM',
  ),
  RealStoryLink(
    title: 'Delhi Jeweller Duped Of Lakhs By SMS Scammer',
    channel: 'NDTV',
    url: 'https://youtu.be/SVkwlIwO1Cs',
    videoId: 'SVkwlIwO1Cs',
  ),
  RealStoryLink(
    title: 'Union Bank fraud, 5 लाख की धोखाधड़ी चेक के द्वारा धोखाधड़ी परिवार सदमे में',
    channel: 'The Kalam News',
    url: 'https://youtu.be/tGARUhyO1cs',
    videoId: 'tGARUhyO1cs',
  ),
];

class StoryLinksSection extends StatelessWidget {
  const StoryLinksSection({super.key});

  Future<void> _open(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the video.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'REAL SCAM STORIES',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Real news coverage — worth watching.',
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 14),
        ..._realStories.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _open(context, s.url),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.bgSurface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 64,
                            height: 48,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  s.thumbnailUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: AppColors.bgRaised,
                                    child: const Icon(Icons.play_circle_outline,
                                        color: AppColors.accent, size: 24),
                                  ),
                                ),
                                Container(color: Colors.black26),
                                const Center(
                                  child: Icon(Icons.play_arrow, color: Colors.white, size: 22),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.title,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                s.channel,
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.open_in_new,
                            color: AppColors.textMuted, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
            )),
      ],
    );
  }
}