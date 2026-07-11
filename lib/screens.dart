import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'logic.dart';
import 'theme.dart';

// Helper for UI localization based on selected language
bool isBengaliUi(String language) {
  return language == 'Bengali' || language == 'Banglish';
}

// Neomorphic Banner Ad Widget
class NeomorphicAdBanner extends StatefulWidget {
  const NeomorphicAdBanner({Key? key}) : super(key: key);

  @override
  State<NeomorphicAdBanner> createState() => _NeomorphicAdBannerState();
}

class _NeomorphicAdBannerState extends State<NeomorphicAdBanner> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-5125220264235408/7660350782', // Banner Ad Unit ID
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, err) {
          debugPrint('BannerAd failed to load: $err');
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: AppTheme.neomorphicCard(radius: 12),
      padding: const EdgeInsets.all(4),
      alignment: Alignment.center,
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}

// AdManager to handle preloading and serving Rewarded Ad
class AdManager {
  static RewardedAd? _rewardedAd;
  static bool _isAdLoading = false;

  static void loadRewardedAd() {
    if (_isAdLoading || _rewardedAd != null) return;
    _isAdLoading = true;
    RewardedAd.load(
      adUnitId: 'ca-app-pub-5125220264235408/5991633209', // Rewarded Ad Unit ID
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isAdLoading = false;
        },
        onAdFailedToLoad: (err) {
          _rewardedAd = null;
          _isAdLoading = false;
          debugPrint('RewardedAd failed to load: $err');
        },
      ),
    );
  }

  static void showRewardedAd({
    required VoidCallback onAdDismissedOrRewarded,
  }) {
    if (_rewardedAd == null) {
      loadRewardedAd();
      onAdDismissedOrRewarded();
      return;
    }

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd();
        onAdDismissedOrRewarded();
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd();
        onAdDismissedOrRewarded();
      },
    );

    _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        // User earned reward
      },
    );
  }
}


// App Launcher (First Launch director)
class AppLauncher extends ConsumerStatefulWidget {
  const AppLauncher({Key? key}) : super(key: key);

  @override
  ConsumerState<AppLauncher> createState() => _AppLauncherState();
}

class _AppLauncherState extends ConsumerState<AppLauncher> {
  @override
  Widget build(BuildContext context) {
    final isFirst = HistoryService.isFirstLaunch();
    if (isFirst) {
      return const OnboardingScreen();
    } else {
      return const SplashScreen();
    }
  }
}

// Premium 3D Neomorphic Splash Screen
class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _controller.forward();

    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 140,
                height: 140,
                decoration: AppTheme.neomorphicCard(radius: 36),
                padding: const EdgeInsets.all(18),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    'assets/app_icon.jpeg',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 50,
                      color: AppTheme.accent,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                'ReplySnap',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accent,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Smart Offline Replies / ইনস্ট্যান্ট রিপ্লাই',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Premium Onboarding Flow
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  String _selectedLanguage = 'English';

  final List<Map<String, dynamic>> _slides = [
    {
      'icon': Icons.lock_person_outlined,
      'title': '100% Offline Privacy',
      'subTitle': '১০০% অফলাইন নিরাপত্তা',
      'desc': 'All text extraction and reply generation happens completely on your device. Your data never goes to any cloud or server.',
      'descBn': 'আপনার স্ক্রিনশট বা কোনো ফাইল আমাদের সার্ভারে আপলোড করা হয় না। প্রসেসিং আপনার ফোনেই সম্পন্ন হয়।',
    },
    {
      'icon': Icons.quickreply_outlined,
      'title': 'Smart Multi-Tone Replies',
      'subTitle': 'মাল্টি-টোন স্মার্ট রিপ্লাই',
      'desc': 'Detects intent automatically and offers multiple reply styles (Polite, Funny, Formal, Direct) in trending languages.',
      'descBn': 'মেসেজের ধরন বুঝে বিনয়ী, মজার, ফরমাল বা সরাসরি উত্তর তৈরি করুন মুহূর্তের মধ্যেই।',
    },
    {
      'icon': Icons.translate_rounded,
      'title': 'Select Default Language',
      'subTitle': 'ডিফল্ট ভাষা নির্বাচন করুন',
      'desc': 'Choose your primary language for generating reply cards. You can change this anytime later.',
      'descBn': 'আপনার রিপ্লাই কার্ডগুলোর জন্য প্রাথমিক ভাষাটি বেছে নিন। এটি যেকোনো সময় পরিবর্তন করা যাবে।',
    }
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _slides.length,
                  onPageChanged: (idx) => setState(() => _currentPage = idx),
                  itemBuilder: (context, idx) {
                    final slide = _slides[idx];
                    final isLastPage = idx == _slides.length - 1;

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: AppTheme.neomorphicCard(radius: 28),
                          child: Icon(slide['icon'], size: 44, color: AppTheme.accent),
                        ),
                        const SizedBox(height: 35),
                        Text(
                          slide['title'],
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.text),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          slide['subTitle'],
                          style: const TextStyle(fontSize: 16, color: AppTheme.textMuted, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            slide['desc'],
                            style: const TextStyle(fontSize: 14, color: AppTheme.text, height: 1.4),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: Text(
                            slide['descBn'],
                            style: const TextStyle(fontSize: 13, color: AppTheme.textMuted, height: 1.4),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        if (isLastPage) ...[
                          const SizedBox(height: 30),
                          const Text(
                            'Languages / ভাষা সমূহ:',
                            style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.text, fontSize: 15),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 54,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              children: ['English', 'Hindi', 'Hinglish', 'Bengali', 'Banglish', 'Tamil', 'Telugu'].map((l) {
                                final isSel = _selectedLanguage == l;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 10, bottom: 6),
                                  child: NeomorphicButton(
                                    radius: 18,
                                    isSelected: isSel,
                                    onTap: () => setState(() => _selectedLanguage = l),
                                    child: Center(
                                      child: Text(
                                        l,
                                        style: TextStyle(
                                          color: isSel ? AppTheme.accent : AppTheme.text,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ]
                      ],
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: List.generate(_slides.length, (index) {
                      final isSel = _currentPage == index;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isSel ? 24 : 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: isSel ? AppTheme.accent : const Color(0xFFC5D3E8),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      );
                    }),
                  ),
                  _currentPage == _slides.length - 1
                      ? NeomorphicButton(
                          radius: 18,
                          color: AppTheme.accent,
                          onTap: () async {
                            ref.read(replyProvider.notifier).updateLanguage(_selectedLanguage);
                            await HistoryService.setFirstLaunchCompleted();
                            if (mounted) {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (context) => const HomeScreen()),
                              );
                            }
                          },
                          child: const Text(
                            'Get Started / শুরু করুন',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        )
                      : NeomorphicButton(
                          radius: 18,
                          onTap: () {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeInOut,
                            );
                          },
                          child: const Text(
                            'Next / এগিয়ে যান',
                            style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

// Home Screen
class HomeScreen extends ConsumerWidget {
  const HomeScreen({Key? key}) : super(key: key);

  Future<void> _pickImage(BuildContext context, WidgetRef ref) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      ref.read(replyProvider.notifier).reset();
      ref.read(replyProvider.notifier).processImage(image.path);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const OcrPreviewScreen()),
      );
    }
  }

  void _showPasteDialog(BuildContext context, WidgetRef ref, bool isBn) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppTheme.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Container(
          decoration: AppTheme.neomorphicCard(radius: 28),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isBn ? 'Text Paste করুন' : 'Paste Text',
                style: const TextStyle(color: AppTheme.text, fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                decoration: AppTheme.neomorphicReadable(radius: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextField(
                  controller: controller,
                  maxLines: 4,
                  style: const TextStyle(color: AppTheme.text),
                  decoration: InputDecoration(
                    hintText: isBn ? 'এখানে আপনার মেসেজ লিখুন বা পেস্ট করুন...' : 'Write or paste your message here...',
                    hintStyle: const TextStyle(color: AppTheme.textMuted),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  NeomorphicButton(
                    radius: 14,
                    onTap: () => Navigator.pop(context),
                    child: Text(isBn ? 'বাতিল' : 'Cancel', style: const TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 16),
                  NeomorphicButton(
                    radius: 14,
                    color: AppTheme.accent,
                    onTap: () {
                      if (controller.text.trim().isNotEmpty) {
                        ref.read(replyProvider.notifier).reset();
                        ref.read(replyProvider.notifier).updateText(controller.text);
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const OcrPreviewScreen()),
                        );
                      }
                    },
                    child: Text(isBn ? 'এগিয়ে যান' : 'Proceed', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(replyProvider);
    final history = HistoryService.getHistory();
    final isBn = isBengaliUi(state.language);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        title: const Text(
          'ReplySnap',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accent, fontSize: 24),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppTheme.textMuted),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Text(
              isBn ? 'কী উত্তর দেবেন বুঝছেন না?' : 'Not sure what to reply?',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.text),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              isBn ? 'স্ক্রিনশট সিলেক্ট অথবা টেক্সট পেস্ট করে ইনস্ট্যান্ট রিপ্লাই পান।' : 'Select screenshot or paste text to get instant replies.',
              style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 25),

            // Select Image Action Button
            NeomorphicButton(
              onTap: () => _pickImage(context, ref),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_photo_alternate_outlined, color: AppTheme.accent, size: 22),
                  const SizedBox(width: 12),
                  Text(
                    isBn ? 'Screenshot Select করুন' : 'Select Screenshot',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.text),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Paste Text Action Button
            NeomorphicButton(
              onTap: () => _showPasteDialog(context, ref, isBn),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.assignment_outlined, color: AppTheme.textMuted, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    isBn ? 'Text Paste করুন' : 'Paste Text',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),

            // Native Language Selector on Home Screen
            Text(
              isBn ? 'Active Language / সক্রিয় ভাষা' : 'Active Language',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.text),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 54,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                children: ['English', 'Hindi', 'Hinglish', 'Bengali', 'Banglish', 'Tamil', 'Telugu'].map((l) {
                  final selected = state.language == l;
                  return Padding(
                    padding: const EdgeInsets.only(right: 10, bottom: 6),
                    child: NeomorphicButton(
                      radius: 18,
                      isSelected: selected,
                      onTap: () => ref.read(replyProvider.notifier).updateLanguage(l),
                      child: Center(
                        child: Text(
                          l,
                          style: TextStyle(
                            color: selected ? AppTheme.accent : AppTheme.text,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 25),

            // Quick Reply Packs Section
            Text(
              isBn ? 'কুইক রিপ্লাই প্যাকস' : 'Quick Reply Packs',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.text),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: NeomorphicButton(
                      radius: 16,
                      onTap: () {
                        ref.read(replyProvider.notifier).reset();
                        ref.read(replyProvider.notifier).updateText('Quick pack trigger for Polite No');
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const OcrPreviewScreen()),
                        );
                      },
                      child: const Center(
                        child: Text(
                          'Polite No',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.text),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: NeomorphicButton(
                      radius: 16,
                      onTap: () {
                        ref.read(replyProvider.notifier).reset();
                        ref.read(replyProvider.notifier).updateText('Quick pack trigger for Office Work');
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const OcrPreviewScreen()),
                        );
                      },
                      child: const Center(
                        child: Text(
                          'Office Work',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.text),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: NeomorphicButton(
                      radius: 16,
                      onTap: () {
                        ref.read(replyProvider.notifier).reset();
                        ref.read(replyProvider.notifier).updateText('Quick pack trigger for Customer');
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const OcrPreviewScreen()),
                        );
                      },
                      child: const Center(
                        child: Text(
                          'Greeting',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.text),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 25),

            // Recent History Section
            Text(
              isBn ? 'সাম্প্রতিক হিস্ট্রি' : 'Recent History',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.text),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: history.isEmpty
                  ? Center(
                      child: Text(
                        isBn ? 'এখনো কোনো হিস্ট্রি নেই' : 'No history available yet',
                        style: TextStyle(color: AppTheme.textMuted.withOpacity(0.8), fontSize: 14),
                      ),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: history.length,
                      itemBuilder: (context, index) {
                        final item = history[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Container(
                            decoration: AppTheme.neomorphicCard(radius: 20),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: ListTile(
                                tileColor: Colors.transparent,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                title: Text(
                                  item['original'] ?? '',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.text),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    '${(item['intent'] ?? 'GENERAL').toString().toUpperCase()} • ${item['tone'] ?? 'Polite'} • ${item['language'] ?? 'English'}',
                                    style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                  ),
                                ),
                                trailing: const Icon(Icons.chevron_right, color: AppTheme.accent),
                                onTap: () {
                                  ref.read(replyProvider.notifier).reset();
                                  ref.read(replyProvider.notifier).updateText(item['original'] ?? '');
                                  ref.read(replyProvider.notifier).updateLanguage(item['language'] ?? 'English');
                                  ref.read(replyProvider.notifier).updateTone(item['tone'] ?? 'Polite');
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const OcrPreviewScreen()),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const NeomorphicAdBanner(),
          ],
        ),
      ),
    );
  }
}

// OCR Preview Screen
class OcrPreviewScreen extends ConsumerStatefulWidget {
  const OcrPreviewScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<OcrPreviewScreen> createState() => _OcrPreviewScreenState();
}

class _OcrPreviewScreenState extends ConsumerState<OcrPreviewScreen> {
  late TextEditingController _controller;
  bool _redactToggle = true;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(replyProvider);
    final isBn = isBengaliUi(state.language);

    // Sync input text dynamically
    final activeText = _redactToggle ? state.redactedText : state.rawText;
    if (_controller.text != activeText) {
      final oldSelection = _controller.selection;
      _controller.text = activeText;
      try {
        _controller.selection = oldSelection;
      } catch (_) {}
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        title: Text(isBn ? 'সনাক্তকৃত টেক্সট' : 'Extracted Text', style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 10),
                // OCR Text Display Area
                Container(
                  decoration: AppTheme.neomorphicReadable(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        controller: _controller,
                        maxLines: 5,
                        style: const TextStyle(color: AppTheme.text, fontSize: 15, height: 1.4),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: isBn ? 'কোনো টেক্সট পাওয়া যায়নি। এখানে লিখুন...' : 'No text extracted. Write here...',
                        ),
                        onChanged: (val) {
                          if (_redactToggle) {
                            ref.read(replyProvider.notifier).updateRedactedText(val);
                          } else {
                            ref.read(replyProvider.notifier).updateText(val);
                          }
                        },
                      ),
                      const Divider(color: Color(0xFFC5D3E8), height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isBn ? 'Privacy / লুকানো তথ্য' : 'Privacy / Redact Info',
                            style: const TextStyle(color: AppTheme.text, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          Switch(
                            value: _redactToggle,
                            activeColor: AppTheme.accent,
                            activeTrackColor: AppTheme.accent.withOpacity(0.3),
                            inactiveTrackColor: Colors.black12,
                            onChanged: (val) {
                              setState(() {
                                _redactToggle = val;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 25),

                // Intent Selector
                Text(
                  isBn ? 'Message Type / মেসেজের ধরন' : 'Message Type / Intent',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.text),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: AppTheme.neomorphicCard(radius: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButtonFormField<MessageIntent>(
                      dropdownColor: AppTheme.surface,
                      decoration: const InputDecoration(border: InputBorder.none),
                      value: state.intent,
                      items: MessageIntent.values.map((intent) {
                        return DropdownMenuItem(
                          value: intent,
                          child: Text(intent.name.toUpperCase(), style: const TextStyle(color: AppTheme.text, fontWeight: FontWeight.bold)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          ref.read(replyProvider.notifier).updateIntent(val);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 25),

                // Tone Selector
                Text(
                  isBn ? 'Tone / ভঙ্গি' : 'Tone / Style',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.text),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 56,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    children: ['Polite', 'Friendly', 'Formal', 'Direct', 'Funny', 'Polite No'].map((t) {
                      final selected = state.tone == t;
                      return Padding(
                        padding: const EdgeInsets.only(right: 12, bottom: 6),
                        child: NeomorphicButton(
                          radius: 20,
                          isSelected: selected,
                          onTap: () => ref.read(replyProvider.notifier).updateTone(t),
                          child: Center(
                            child: Text(
                              t,
                              style: TextStyle(
                                color: selected ? AppTheme.accent : AppTheme.text,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 25),

                // Language Selector
                Text(
                  isBn ? 'Language / ভাষা' : 'Language / Translation',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.text),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 56,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    children: ['English', 'Hindi', 'Hinglish', 'Bengali', 'Banglish', 'Tamil', 'Telugu'].map((l) {
                      final selected = state.language == l;
                      return Padding(
                        padding: const EdgeInsets.only(right: 12, bottom: 6),
                        child: NeomorphicButton(
                          radius: 20,
                          isSelected: selected,
                          onTap: () => ref.read(replyProvider.notifier).updateLanguage(l),
                          child: Center(
                            child: Text(
                              l,
                              style: TextStyle(
                                color: selected ? AppTheme.accent : AppTheme.text,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 40),

                // Action Button
                NeomorphicButton(
                  radius: 20,
                  onTap: () {
                    final currentCount = HistoryService.getGenerationCount();
                    if (currentCount >= 3) {
                      showDialog(
                        context: context,
                        builder: (context) => Dialog(
                          backgroundColor: AppTheme.background,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                          child: Container(
                            decoration: AppTheme.neomorphicCard(radius: 28),
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  isBn ? 'সীমাবদ্ধতা অতিক্রম করেছেন' : 'Limit Reached',
                                  style: const TextStyle(color: AppTheme.text, fontSize: 18, fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  isBn
                                      ? 'পরবর্তী ৩টি রিপ্লাই তৈরির কাজ আনলক করতে অনুগ্রহ করে একটি ছোট ভিডিও বিজ্ঞাপন দেখুন।'
                                      : 'Please watch a short video ad to unlock your next 3 reply generations.',
                                  style: const TextStyle(color: AppTheme.textMuted, height: 1.4),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    NeomorphicButton(
                                      radius: 14,
                                      onTap: () => Navigator.pop(context),
                                      child: Text(isBn ? 'বাতিল' : 'Cancel', style: const TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(width: 16),
                                    NeomorphicButton(
                                      radius: 14,
                                      color: AppTheme.accent,
                                      onTap: () {
                                        Navigator.pop(context);
                                        AdManager.showRewardedAd(
                                          onAdDismissedOrRewarded: () {
                                            HistoryService.resetGenerationCount();
                                            ref.read(replyProvider.notifier).generateReplies();
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(builder: (context) => const ResultScreen()),
                                            );
                                          },
                                        );
                                      },
                                      child: Text(isBn ? 'বিজ্ঞাপন দেখুন' : 'Watch Ad', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    } else {
                      HistoryService.incrementGenerationCount();
                      ref.read(replyProvider.notifier).generateReplies();
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ResultScreen()),
                      );
                    }
                  },
                  color: AppTheme.accent,
                  child: Center(
                    child: Text(
                      isBn ? 'রিপ্লাই তৈরি করুন' : 'Generate Replies',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Result Screen
class ResultScreen extends ConsumerWidget {
  const ResultScreen({Key? key}) : super(key: key);

  void _copyToClipboard(BuildContext context, String text, bool isBn) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isBn ? 'কপি করা হয়েছে! এখন চ্যাটে পেস্ট করুন।' : 'Copied to clipboard! Paste in chat.'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _shareReply(String text) {
    Share.share(text);
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, String reply, int index, bool isBn) {
    final controller = TextEditingController(text: reply);
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppTheme.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Container(
          decoration: AppTheme.neomorphicCard(radius: 28),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isBn ? 'উত্তর এডিট করুন' : 'Edit Reply',
                style: const TextStyle(color: AppTheme.text, fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                decoration: AppTheme.neomorphicReadable(radius: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextField(
                  controller: controller,
                  maxLines: 4,
                  style: const TextStyle(color: AppTheme.text),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  NeomorphicButton(
                    radius: 14,
                    onTap: () => Navigator.pop(context),
                    child: Text(isBn ? 'বাতিল' : 'Cancel', style: const TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 16),
                  NeomorphicButton(
                    radius: 14,
                    color: AppTheme.accent,
                    onTap: () {
                      if (controller.text.trim().isNotEmpty) {
                        final state = ref.read(replyProvider);
                        final updatedList = List<String>.from(state.generatedReplies);
                        updatedList[index] = controller.text;
                        ref.read(replyProvider.notifier).state = state.copyWith(generatedReplies: updatedList);
                        Navigator.pop(context);
                      }
                    },
                    child: Text(isBn ? 'সেভ' : 'Save', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(replyProvider);
    final replies = state.generatedReplies;
    final isBn = isBengaliUi(state.language);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        title: Text(isBn ? 'আপনার রিপ্লাইসমূহ' : 'Suggested Replies', style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Text(
              isBn ? 'সবচেয়ে ভালো উত্তরটি বেছে নিয়ে কপি করুন:' : 'Select the best reply to copy:',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 15),
            Expanded(
              child: replies.isEmpty
                  ? Center(
                      child: Text(
                        isBn ? 'কোনো রিপ্লাই তৈরি করা যায়নি। আবার চেষ্টা করুন।' : 'No replies generated. Try again.',
                        style: const TextStyle(color: AppTheme.textMuted),
                      ),
                    )
                  : ListView.builder(
                      itemCount: replies.length,
                      physics: const BouncingScrollPhysics(),
                      itemBuilder: (context, index) {
                        final reply = replies[index];
                        final listLabels = ['Short', 'Balanced', 'Alternative'];
                        final label = index < listLabels.length ? listLabels[index] : 'Option';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 24),
                          decoration: AppTheme.neomorphicReadable(radius: 20),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.accent.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      label,
                                      style: const TextStyle(
                                          color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.textMuted),
                                        onPressed: () => _showEditDialog(context, ref, reply, index, isBn),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.bookmark_border_outlined, size: 18, color: AppTheme.textMuted),
                                        onPressed: () {
                                          HistoryService.toggleFavorite(reply);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(isBn ? 'বুকমার্কে সংরক্ষণ করা হয়েছে।' : 'Added to favorites.'),
                                              backgroundColor: AppTheme.accent,
                                            ),
                                          );
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.share_outlined, size: 18, color: AppTheme.textMuted),
                                        onPressed: () => _shareReply(reply),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                reply,
                                style: const TextStyle(color: AppTheme.text, fontSize: 16, height: 1.4),
                              ),
                              const SizedBox(height: 18),
                              NeomorphicButton(
                                radius: 14,
                                onTap: () => _copyToClipboard(context, reply, isBn),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.copy, size: 16, color: AppTheme.accent),
                                    const SizedBox(width: 8),
                                    Text(
                                      isBn ? 'উত্তর কপি করুন' : 'Copy Reply',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.text),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              icon: const Icon(Icons.refresh, color: AppTheme.accent),
              label: Text(
                isBn ? 'নতুন অপশন তৈরি করুন' : 'Regenerate Options',
                style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                final currentCount = HistoryService.getRegenerateCount();
                if (currentCount >= 3) {
                  showDialog(
                    context: context,
                    builder: (context) => Dialog(
                      backgroundColor: AppTheme.background,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                      child: Container(
                        decoration: AppTheme.neomorphicCard(radius: 28),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              isBn ? 'সীমাবদ্ধতা অতিক্রম করেছেন' : 'Limit Reached',
                              style: const TextStyle(color: AppTheme.text, fontSize: 18, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              isBn
                                  ? 'পরবর্তী ৩টি নতুন উত্তর তৈরি করতে অনুগ্রহ করে একটি ছোট ভিডিও বিজ্ঞাপন দেখুন।'
                                  : 'Please watch a short video ad to unlock another 3 regeneration attempts.',
                              style: const TextStyle(color: AppTheme.textMuted, height: 1.4),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                NeomorphicButton(
                                  radius: 14,
                                  onTap: () => Navigator.pop(context),
                                  child: Text(isBn ? 'বাতিল' : 'Cancel', style: const TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 16),
                                NeomorphicButton(
                                  radius: 14,
                                  color: AppTheme.accent,
                                  onTap: () {
                                    Navigator.pop(context);
                                    AdManager.showRewardedAd(
                                      onAdDismissedOrRewarded: () {
                                        HistoryService.resetRegenerateCount();
                                        ref.read(replyProvider.notifier).generateReplies();
                                      },
                                    );
                                  },
                                  child: Text(isBn ? 'বিজ্ঞাপন দেখুন' : 'Watch Ad', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                } else {
                  HistoryService.incrementRegenerateCount();
                  ref.read(replyProvider.notifier).generateReplies();
                }
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// Settings Screen
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(replyProvider);
    final isBn = isBengaliUi(state.language);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        title: Text(isBn ? 'Settings / সেটিংস' : 'Settings', style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 10),
                
                // Section 1: Privacy / লুকানো তথ্য
                Text(
                  isBn ? 'Privacy / লুকানো তথ্য' : 'Privacy & Safety',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.accent),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: AppTheme.neomorphicCard(radius: 16),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isBn ? 'সম্পূর্ণ অফলাইন OCR' : '100% Offline OCR',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.text),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isBn
                                      ? 'আপনার স্ক্রিনশট বা লেখা কখনো কোনো সার্ভারে আপলোড করা হয় না। প্রসেসিং ডিভাইসেই সম্পন্ন হয়।'
                                      : 'Your screenshots or text are never uploaded to any server. Processing is 100% local.',
                                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.offline_bolt_outlined, color: AppTheme.accent, size: 28),
                        ],
                      ),
                      const Divider(color: Color(0xFFC5D3E8), height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isBn ? 'স্বয়ংক্রিয় প্রাইভেসী মাস্কিং' : 'Automatic Privacy Masking',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.text),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isBn
                                      ? 'ফোন নাম্বার, ইমেইল এবং ওটিপি কোডগুলো জেনারেশনের আগেই স্বয়ংক্রিয়ভাবে লুকিয়ে ফেলা হয়।'
                                      : 'Phone numbers, emails, and OTP codes are automatically redacted before replies are generated.',
                                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.enhanced_encryption_outlined, color: Colors.green, size: 28),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // Section 2: Default Language / ডিফল্ট ভাষা
                Text(
                  isBn ? 'Default Language / ডিফল্ট ভাষা' : 'Default Language',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.accent),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: AppTheme.neomorphicCard(radius: 16),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isBn ? 'রিপ্লাই তৈরির ডিফল্ট ভাষা নির্বাচন করুন:' : 'Select default language for reply cards:',
                        style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 50,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          children: ['English', 'Hindi', 'Hinglish', 'Bengali', 'Banglish', 'Tamil', 'Telugu'].map((l) {
                            final selected = state.language == l;
                            return Padding(
                              padding: const EdgeInsets.only(right: 10, bottom: 4),
                              child: NeomorphicButton(
                                radius: 16,
                                isSelected: selected,
                                onTap: () => ref.read(replyProvider.notifier).updateLanguage(l),
                                child: Center(
                                  child: Text(
                                    l,
                                    style: TextStyle(
                                      color: selected ? AppTheme.accent : AppTheme.text,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                
                // Section 3: Data Management / ডাটা ম্যানেজমেন্ট
                Text(
                  isBn ? 'Data / ডাটা ম্যানেজমেন্ট' : 'Data Management',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.accent),
                ),
                const SizedBox(height: 12),
                NeomorphicButton(
                  color: AppTheme.surface,
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => Dialog(
                        backgroundColor: AppTheme.background,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                        child: Container(
                          decoration: AppTheme.neomorphicCard(radius: 28),
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                isBn ? 'হিস্ট্রি মুছুন' : 'Clear History',
                                style: const TextStyle(color: AppTheme.text, fontSize: 18, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                isBn
                                    ? 'আপনি কি নিশ্চিত যে আপনার সমস্ত সাম্প্রতিক হিস্ট্রি মুছে ফেলতে চান? এটি আর ফিরিয়ে আনা যাবে না।'
                                    : 'Are you sure you want to clear your recent history? This action cannot be undone.',
                                style: const TextStyle(color: AppTheme.textMuted, height: 1.4),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  NeomorphicButton(
                                    radius: 14,
                                    onTap: () => Navigator.pop(context),
                                    child: Text(isBn ? 'বাতিল' : 'Cancel', style: const TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 16),
                                  NeomorphicButton(
                                    radius: 14,
                                    color: Colors.redAccent,
                                    onTap: () async {
                                      await HistoryService.clearHistory();
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(isBn ? 'সাম্প্রতিক হিস্ট্রি সম্পূর্ণরূপে মুছে ফেলা হয়েছে!' : 'Recent history cleared successfully!'),
                                          backgroundColor: Colors.redAccent,
                                        ),
                                      );
                                    },
                                    child: Text(isBn ? 'মুছে ফেলুন' : 'Clear', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent, size: 24),
                      const SizedBox(width: 12),
                      Text(
                        isBn ? 'সাম্প্রতিক হিস্ট্রি মুছুন' : 'Clear Recent History',
                        style: const TextStyle(color: AppTheme.text, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // Section 4: App Information / অ্যাপ সম্পর্কিত তথ্য
                Text(
                  isBn ? 'About / অ্যাপ সম্পর্কিত' : 'About App',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.accent),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: AppTheme.neomorphicCard(radius: 16),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(isBn ? 'সংস্করণ' : 'Version', style: const TextStyle(color: AppTheme.text)),
                          const Text('1.0.0 (MVP)', style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const Divider(color: Color(0xFFC5D3E8), height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(isBn ? 'ডেভেলপার' : 'Developer', style: const TextStyle(color: AppTheme.text)),
                          const Text('FarKode', style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const Divider(color: Color(0xFFC5D3E8), height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(isBn ? 'লাইসেন্স' : 'License', style: const TextStyle(color: AppTheme.text)),
                          const Text('MIT License', style: TextStyle(color: AppTheme.textMuted)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
