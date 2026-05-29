---
name: user_architectural_pivot_cobalt_api
description: User requested migration from YouTube-only extraction to universal Cobalt API architecture
metadata:
  type: user
---

User is a Flutter developer who has decided to pivot the Mun Down app architecture from client-side YouTube extraction (using youtube_explode_dart) to a Universal Server-Side API Architecture utilizing the Cobalt API. This change allows the app to support downloads from multiple platforms (YouTube, TikTok, Instagram, X, etc.) seamlessly and offloads decryption/stitching overhead from mobile devices.

Key requirements implemented:
1. Updated downloader_remote_data_source.dart to use Cobalt API for all media URLs
2. Removed youtube_explode_dart dependency and related files
3. Maintained backward compatibility with existing DownloadEntity and DownloadMetadata structures
4. Preserved progress reporting through onReceiveProgress for BLoC layer notifications
5. Handled Cobalt API response statuses (redirect/tunnel/picker/error) appropriately

The user emphasized strict adherence to Clean Architecture principles and keeping domain/presentation layers untouched.
---