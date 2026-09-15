// lib/screens/dictionary_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../model/rule_entry.dart';
import '../services/rules_service.dart';
import '../theme/app_theme.dart';
import '../widgets/aegis_widgets.dart';
import 'package:url_launcher/url_launcher.dart';

enum DictionaryPhase { loading, loaded, error }

class _VerifyTool {
  final String name;
  final String description;
  final String url;
  final IconData icon;
  const _VerifyTool({
    required this.name,
    required this.description,
    required this.url,
    required this.icon,
  });
}

const _verifyTools = <_VerifyTool>[
  _VerifyTool(
    name: 'Sanchar Saathi (TAFCOP)',
    description:
        'Check every mobile number registered in your name, and report or block any you don\'t recognize. Directly checks the "your SIM is being misused" claim scammers make.',
    url: 'https://sancharsaathi.gov.in/',
    icon: Icons.sim_card_outlined,
  ),
  _VerifyTool(
    name: 'UIDAI — Aadhaar Services',
    description:
        'Verify your Aadhaar details and authentication history directly with the issuing authority. Useful when a caller claims your Aadhaar is linked to a crime.',
    url: 'https://uidai.gov.in/',
    icon: Icons.badge_outlined,
  ),
];

class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({super.key});
  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  final _service = RulesService();

  DictionaryPhase _phase = DictionaryPhase.loading;
  RulesDictionary? _dictionary;
  String _errorText = '';
  int? _expandedIndex;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _phase = DictionaryPhase.loading);
    try {
      final dict = await _service.fetchDictionary();
      setState(() {
        _dictionary = dict;
        _phase = DictionaryPhase.loaded;
      });
    } catch (e) {
      setState(() {
        _phase = DictionaryPhase.error;
        _errorText = 'Couldn\'t load the rules dictionary. $e';
      });
    }
  }

  void _copySource(String url) {
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Source link copied')),
    );
  }
  Future<void> _openTool(String url) async {
  final uri = Uri.parse(url);
  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!launched && mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open the link.')),
    );
  }
}

Widget _buildVerifyCard(_VerifyTool tool) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openTool(tool.url),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(tool.icon, size: 18, color: AppColors.accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tool.name,
                        style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    Text(tool.description,
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            height: 1.4,
                            color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.open_in_new, size: 16, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return GridBackground(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: KeyedSubtree(
              key: ValueKey(_phase),
              child: _buildPhase(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhase() {
    switch (_phase) {
      case DictionaryPhase.loading:
        return _buildLoading();
      case DictionaryPhase.loaded:
        return _buildLoaded();
      case DictionaryPhase.error:
        return _buildError();
    }
  }

  // ---------- LOADING ----------
  Widget _buildLoading() {
    return SizedBox(
      width: double.infinity,
      height: MediaQuery.of(context).size.height * 0.8,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const AegisLogo(size: 72, showText: false)
              .animate(onPlay: (c) => c.repeat())
              .rotate(duration: 2400.ms),
          const SizedBox(height: 24),
          Text(
            'Loading the rules dictionary...',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ---------- LOADED ----------
  Widget _buildLoaded() {
    final dict = _dictionary!;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          Text(
            'Rules & Regulations',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'What\'s actually true — sourced from real advisories, not guesses.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          _buildEmergencyCard(dict.emergencyContacts),
          const SizedBox(height: 24),
          ...dict.entries.asMap().entries.map((e) {
            final i = e.key;
            final rule = e.value;
            return _buildRuleCard(i, rule);
          }),
          if (dict.universalPatterns.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'GENERAL RED FLAGS',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                color: AppColors.textMuted,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            ...dict.universalPatterns.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Icon(Icons.circle,
                          size: 6, color: AppColors.accent),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        p,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          height: 1.45,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 28),
            Text(
              'VERIFY THIS YOURSELF',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                color: AppColors.textMuted,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Don\'t take a caller\'s word for it — check these official sources directly.',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            ..._verifyTools.map((t) => _buildVerifyCard(t)),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: const [
        AegisLogo(size: 32, showText: false),
        StatusPill(label: 'DICTIONARY', dotColor: AppColors.accent),
      ],
    );
  }

  Widget _buildEmergencyCard(Map<String, String> contacts) {
    final helpline = contacts['cyber_crime_helpline'] ?? '1930';
    final portal = contacts['cyber_crime_portal'] ?? 'cybercrime.gov.in';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.riskHigh.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.riskHigh.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.phone_in_talk, color: AppColors.riskHigh, size: 26),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Being scammed right now? Call $helpline',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'or report at $portal — 24/7, run by India\'s Cyber Crime Coordination Centre.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildRuleCard(int index, RuleEntry rule) {
    final expanded = _expandedIndex == index;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => setState(() => _expandedIndex = expanded ? null : index),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_iconFor(rule.category),
                        size: 18, color: AppColors.accent),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _categoryLabel(rule.category),
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            color: AppColors.textMuted,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          rule.rule,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
              if (expanded) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.bgRaised,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'WATCH FOR',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          color: AppColors.textMuted,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        rule.redFlagContext,
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          height: 1.45,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: rule.sourceUrl.isEmpty
                      ? null
                      : () => _copySource(rule.sourceUrl),
                  child: Row(
                    children: [
                      const Icon(Icons.link, size: 14, color: AppColors.accent),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          rule.source,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.accent,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    )
        .animate(delay: (index * 60).ms)
        .fadeIn(duration: 250.ms)
        .slideY(begin: 0.08, end: 0);
  }

  // ---------- ERROR ----------
  Widget _buildError() {
    return SizedBox(
      width: double.infinity,
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off, size: 64, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text(
            'Couldn\'t load the dictionary',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Check your connection and try again.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: PrimaryButton(
              onPressed: _load,
              label: 'Try Again',
              icon: Icons.refresh,
            ),
          ),
        ],
      ),
    );
  }

  String _categoryLabel(String category) {
    switch (category) {
      case 'otp_kyc':
        return 'OTP & KYC REQUESTS';
      case 'rbi_impersonation':
        return 'RBI / BANK IMPERSONATION';
      case 'upi_request_money':
        return 'UPI PAYMENT REQUESTS';
      case 'investment_job_scam':
        return 'INVESTMENT & JOB OFFERS';
      case 'reporting':
        return 'REPORTING A SCAM';
      case 'digital_arrest':
        return 'DIGITAL ARREST CALLS';
      default:
        return category.replaceAll('_', ' ').toUpperCase();
    }
  }

  IconData _iconFor(String category) {
    switch (category) {
      case 'otp_kyc':
        return Icons.lock_outline;
      case 'rbi_impersonation':
        return Icons.account_balance;
      case 'upi_request_money':
        return Icons.qr_code;
      case 'investment_job_scam':
        return Icons.work_outline;
      case 'reporting':
        return Icons.report_outlined;
      case 'digital_arrest':
        return Icons.local_police_outlined;
      default:
        return Icons.info_outline;
    }
  }
}