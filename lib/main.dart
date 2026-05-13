import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/themes/app_theme.dart';
import 'features/downloader/presentation/bloc/downloader_bloc.dart';
import 'features/downloader/presentation/pages/downloader_page.dart';
import 'injection_container.dart' as di;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize dependency injection
  await di.init();

  runApp(const MunDownApp());
}

class MunDownApp extends StatelessWidget {
  const MunDownApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MunDown',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: BlocProvider<DownloaderBloc>(
        create: (_) => di.sl<DownloaderBloc>(),
        child: const DownloaderPage(),
      ),
    );
  }
}
