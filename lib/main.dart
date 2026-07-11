import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'logic.dart';
import 'screens.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize MobileAds safely
  try {
    await MobileAds.instance.initialize();
    AdManager.loadRewardedAd(); // Preload rewarded video ad at startup
  } catch (e) {
    debugPrint("MobileAds initialization skipped: $e");
  }

  // Initialize Firebase safely (will skip gracefully if configuration is not set up)
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase initialization skipped: $e");
  }

  await HistoryService.init();
  runApp(const ProviderScope(child: ReplySnapApp()));
}

class ReplySnapApp extends ConsumerStatefulWidget {
  const ReplySnapApp({Key? key}) : super(key: key);

  @override
  ConsumerState<ReplySnapApp> createState() => _ReplySnapAppState();
}

class _ReplySnapAppState extends ConsumerState<ReplySnapApp> {
  late StreamSubscription _intentDataStreamSubscription;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    
    // Listen for shared media files when app is in background/foreground
    _intentDataStreamSubscription = ReceiveSharingIntent.instance.getMediaStream().listen((value) {
      if (value.isNotEmpty) {
        _handleSharedFile(value.first.path);
      }
    }, onError: (err) {
      debugPrint("ReceiveSharingIntent error: $err");
    });

    // Handle shared media file when app is launched from closed state
    ReceiveSharingIntent.instance.getInitialMedia().then((value) {
      if (value.isNotEmpty) {
        _handleSharedFile(value.first.path);
      }
    });
  }

  void _handleSharedFile(String path) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(replyProvider.notifier).reset();
      ref.read(replyProvider.notifier).processImage(path);
      _navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (context) => const OcrPreviewScreen()),
      );
    });
  }

  @override
  void dispose() {
    _intentDataStreamSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'ReplySnap',
      theme: AppTheme.lightTheme,
      home: const AppLauncher(),
      debugShowCheckedModeBanner: false,
    );
  }
}
