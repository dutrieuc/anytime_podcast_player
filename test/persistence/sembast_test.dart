// Copyright 2020 Ben Hills. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:anytime/entities/downloadable.dart';
import 'package:anytime/entities/episode.dart';
import 'package:anytime/entities/podcast.dart';
import 'package:anytime/repository/repository.dart';
import 'package:anytime/repository/sembast/sembast_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class MockPathProvder extends PathProviderPlatform {
  Future<Directory> getApplicationDocumentsDirectory() {
    return Future.value(Directory.systemTemp);
  }

  @override
  Future<String> getApplicationDocumentsPath() {
    return Future.value(Directory.systemTemp.path);
  }
}

void main() {
  MockPathProvder mockPath;
  Repository persistenceService;

  Podcast podcast1;
  Podcast podcast2;
  Podcast podcast3;

  setUp(() async {
    mockPath = MockPathProvder();
    PathProviderPlatform.instance = mockPath;
    disablePathProviderPlatformOverride = true;
    persistenceService = SembastRepository();

    podcast1 =
        Podcast(title: 'Podcast 1', description: '1st podcast', guid: 'http://p1.com', link: 'http://p1.com', url: 'http://p1.com');

    podcast2 =
        Podcast(title: 'Podcast 2', description: '2nd podcast', guid: 'http://p2.com', link: 'http://p2.com', url: 'http://p2.com');

    podcast3 =
        Podcast(title: 'Podcast 3', description: '3rd podcast', guid: 'http://p3.com', link: 'http://p3.com', url: 'http://p3.com');
  });

  tearDown(() async {
    // Sembast will cache data so simply deleting the file and clearing the
    // object reference will not do. Close the database and delete the db file.
    await persistenceService.close();

    persistenceService = null;

    var f = File('${Directory.systemTemp.path}/anytime.db');

    if (f.existsSync()) {
      f.deleteSync();
    }
  });

  test('Fetch podcast with non-existent ID', () async {
    var result = await persistenceService.findPodcastById(123);

    expect(result, null);
  });

  /// Test the creation and retrieval of podcasts both with and without
  /// episodes. Ensure that data fetched is equal to the data originally
  /// stored.
  group('Podcast creation and retrieval', () {
    test('Create and save a single Podcast without episodes', () async {
      await persistenceService.savePodcast(podcast1);

      expect(true, podcast1.id > 0);
    }, skip: false);

    test('Create and save a single Podcast with episodes', () async {
      podcast2.episodes = <Episode>[
        Episode(guid: 'EP001', title: 'Episode 1', pguid: podcast2.guid, podcast: podcast2.title),
        Episode(guid: 'EP002', title: 'Episode 2', pguid: podcast2.guid, podcast: podcast2.title),
        Episode(guid: 'EP003', title: 'Episode 3', pguid: podcast2.guid, podcast: podcast2.title),
      ];

      await persistenceService.savePodcast(podcast2);

      expect(true, (podcast2.id > 0));
      expect(true, podcast2.episodes.isNotEmpty);
    });

    test('Create and save a single Podcast & attach episodes later', () async {
      await persistenceService.savePodcast(podcast3);

      var previousId = podcast3.id;

      expect(true, (podcast3.id > 0));
      expect(true, podcast3.episodes.isEmpty);

      podcast3.episodes = <Episode>[
        Episode(guid: 'EP001', title: 'Episode 1', pguid: podcast3.guid, podcast: podcast3.title),
        Episode(guid: 'EP002', title: 'Episode 2', pguid: podcast3.guid, podcast: podcast3.title),
        Episode(guid: 'EP003', title: 'Episode 3', pguid: podcast3.guid, podcast: podcast3.title),
      ];

      await persistenceService.savePodcast(podcast3);

      expect(previousId, podcast3.id);
      expect(true, podcast3.episodes.isNotEmpty);
    });

    test('Retrieve an existing Podcast without episodes', () async {
      var podcast1 = Podcast(
          title: 'Podcast 1B', description: '1st podcast', guid: 'http://p1.com', link: 'http://p1.com', url: 'http://p1.com');

      await persistenceService.savePodcast(podcast1);

      expect(true, (podcast1.id > 0));

      var podcast = await persistenceService.findPodcastById(podcast1.id);

      expect(true, podcast == podcast1);
    });

    test('Retrieve an existing Podcast with episodes', () async {
      var podcast3 = Podcast(
          title: 'Podcast 3', description: '3rd podcast', guid: 'http://p3.com', link: 'http://p3.com', url: 'http://p3.com');

      podcast3.episodes = <Episode>[
        Episode(guid: 'EP001', title: 'Episode 1', pguid: podcast3.guid, podcast: podcast3.title),
        Episode(guid: 'EP002', title: 'Episode 2', pguid: podcast3.guid, podcast: podcast3.title),
        Episode(guid: 'EP003', title: 'Episode 3', pguid: podcast3.guid, podcast: podcast3.title),
      ];

      await persistenceService.savePodcast(podcast3);

      var podcast = await persistenceService.findPodcastById(podcast3.id);

      expect(true, podcast == podcast3);
      expect(true, listEquals(podcast.episodes, podcast3.episodes));

      // Retrieve same Podcast via GUID and test it is still the same.
      var podcastByGuid = await persistenceService.findPodcastByGuid(podcast3.guid);

      expect(true, podcastByGuid == podcast3);
      expect(true, listEquals(podcast.episodes, podcast3.episodes));
    });
  });

  group('Multiple Podcast subscription handling', () {
    test('Subscribe to 3 podcasts; one with episodes', () async {
      podcast2.episodes = <Episode>[
        Episode(guid: 'EP001', title: 'Episode 1', pguid: podcast2.guid, podcast: podcast2.title),
        Episode(guid: 'EP002', title: 'Episode 2', pguid: podcast2.guid, podcast: podcast2.title),
        Episode(guid: 'EP003', title: 'Episode 3', pguid: podcast2.guid, podcast: podcast2.title),
      ];

      await persistenceService.savePodcast(podcast1);

      var results = await persistenceService.subscriptions();

      await expect(true, listEquals(results, [podcast1]));

      await persistenceService.savePodcast(podcast2);
      await persistenceService.savePodcast(podcast3);

      results = await persistenceService.subscriptions();

      await expect(
          true,
          listEquals(results, [
            podcast1,
            podcast2,
            podcast3,
          ]));

      await persistenceService.deletePodcast(podcast2);

      results = await persistenceService.subscriptions();

      await expect(
          true,
          listEquals(results, [
            podcast1,
            podcast3,
          ]));
    });
  });

  group('Saving, updating and retrieving episodes', () {
    test('Subscribe to podcasts and retrieve', () async {
      podcast2.episodes = <Episode>[
        Episode(guid: 'EP001', title: 'Episode 1', pguid: podcast2.guid, podcast: podcast2.title),
        Episode(guid: 'EP002', title: 'Episode 2', pguid: podcast2.guid, podcast: podcast2.title),
        Episode(guid: 'EP003', title: 'Episode 3', pguid: podcast2.guid, podcast: podcast2.title),
      ];

      var episode2 = podcast2.episodes[1];

      expect(true, episode2.id == null);

      await persistenceService.savePodcast(podcast1);
      await persistenceService.savePodcast(podcast2);
      await persistenceService.savePodcast(podcast3);

      var podcast = await persistenceService.findPodcastByGuid(podcast2.guid);

      expect(true, listEquals(podcast2.episodes, podcast.episodes));

      var episode = await persistenceService.findEpisodeByGuid(podcast.episodes[1].guid);

      expect(true, episode == episode2);
    });
  });

  group('Saving, updating and retrieving downloaded episodes', () {
    test('Episodes ordered by reverse publication-date', () async {
      var pubDate5 = DateTime.now();
      var pubDate4 = DateTime.now().subtract(Duration(days: 1));
      var pubDate3 = DateTime.now().subtract(Duration(days: 2));
      var pubDate2 = DateTime.now().subtract(Duration(days: 3));
      var pubDate1 = DateTime.now().subtract(Duration(days: 4));

      podcast1.episodes = <Episode>[
        Episode(guid: 'EP001', title: 'Episode 1', pguid: podcast1.guid, podcast: podcast1.title, publicationDate: pubDate1),
        Episode(guid: 'EP002', title: 'Episode 2', pguid: podcast1.guid, podcast: podcast1.title, publicationDate: pubDate2),
        Episode(guid: 'EP005', title: 'Episode 5', pguid: podcast1.guid, podcast: podcast1.title, publicationDate: pubDate5),
        Episode(guid: 'EP004', title: 'Episode 4', pguid: podcast1.guid, podcast: podcast1.title, publicationDate: pubDate4),
        Episode(guid: 'EP003', title: 'Episode 3', pguid: podcast1.guid, podcast: podcast1.title, publicationDate: pubDate3),
      ];

      var orderedEpisodes = <Episode>[
        Episode(guid: 'EP005', title: 'Episode 5', pguid: podcast1.guid, podcast: podcast1.title, publicationDate: pubDate5),
        Episode(guid: 'EP004', title: 'Episode 4', pguid: podcast1.guid, podcast: podcast1.title, publicationDate: pubDate4),
        Episode(guid: 'EP003', title: 'Episode 3', pguid: podcast1.guid, podcast: podcast1.title, publicationDate: pubDate3),
        Episode(guid: 'EP002', title: 'Episode 2', pguid: podcast1.guid, podcast: podcast1.title, publicationDate: pubDate2),
        Episode(guid: 'EP001', title: 'Episode 1', pguid: podcast1.guid, podcast: podcast1.title, publicationDate: pubDate1),
      ];

      await persistenceService.savePodcast(podcast1);
      await persistenceService.savePodcast(podcast2);
      await persistenceService.savePodcast(podcast3);

      // Episodes should be returned in reverse publication-date order.
      var episodes = await persistenceService.findEpisodesByPodcastGuid(podcast1.guid);

      expect(true, listEquals(episodes, orderedEpisodes));
    });

    test('Fetch downloaded episodes', () async {
      var pubDate5 = DateTime.now();
      var pubDate4 = DateTime.now().subtract(Duration(days: 1));
      var pubDate3 = DateTime.now().subtract(Duration(days: 2));
      var pubDate2 = DateTime.now().subtract(Duration(days: 3));
      var pubDate1 = DateTime.now().subtract(Duration(days: 4));

      podcast1.episodes = <Episode>[
        Episode(guid: 'EP001', title: 'Episode 1', pguid: podcast1.guid, podcast: podcast1.title, publicationDate: pubDate1),
        Episode(guid: 'EP002', title: 'Episode 2', pguid: podcast1.guid, podcast: podcast1.title, publicationDate: pubDate2),
        Episode(guid: 'EP005', title: 'Episode 5', pguid: podcast1.guid, podcast: podcast1.title, publicationDate: pubDate5),
        Episode(guid: 'EP004', title: 'Episode 4', pguid: podcast1.guid, podcast: podcast1.title, publicationDate: pubDate4),
        Episode(guid: 'EP003', title: 'Episode 3', pguid: podcast1.guid, podcast: podcast1.title, publicationDate: pubDate3),
      ];

      await persistenceService.savePodcast(podcast1);
      await persistenceService.savePodcast(podcast2);
      await persistenceService.savePodcast(podcast3);

      var noDownloads = await persistenceService.findDownloads();
      var emptyDownloaded = <Episode>[];

      expect(noDownloads, emptyDownloaded);

      var episode1 = await persistenceService.findEpisodeByGuid('EP001');
      var episode2 = await persistenceService.findEpisodeByGuid('EP002');

      expect(true, episode1 == podcast1.episodes[0]);
      expect(true, episode2 == podcast1.episodes[1]);

      // Save one episode as downloaded and re-fetch
      episode1.downloadPercentage = 100;
      episode1.downloadState = DownloadState.downloaded;

      episode2.downloadPercentage = 95;
      episode2.downloadState = DownloadState.downloading;

      await persistenceService.saveEpisode(episode1);
      await persistenceService.saveEpisode(episode2);

      var downloaded = <Episode>[episode1];
      var singleDownload = await persistenceService.findDownloads();

      expect(true, listEquals(singleDownload, downloaded));
    });

    test('Delete downloaded episodes', () async {
      var pubDate5 = DateTime.now();
      var pubDate4 = DateTime.now().subtract(Duration(days: 1));
      var pubDate3 = DateTime.now().subtract(Duration(days: 2));
      var pubDate2 = DateTime.now().subtract(Duration(days: 3));
      var pubDate1 = DateTime.now().subtract(Duration(days: 4));

      podcast1.episodes = <Episode>[
        Episode(guid: 'EP001', title: 'Episode 1', pguid: podcast1.guid, podcast: podcast1.title, publicationDate: pubDate1),
        Episode(guid: 'EP002', title: 'Episode 2', pguid: podcast1.guid, podcast: podcast1.title, publicationDate: pubDate2),
        Episode(guid: 'EP005', title: 'Episode 5', pguid: podcast1.guid, podcast: podcast1.title, publicationDate: pubDate5),
        Episode(guid: 'EP004', title: 'Episode 4', pguid: podcast1.guid, podcast: podcast1.title, publicationDate: pubDate4),
        Episode(guid: 'EP003', title: 'Episode 3', pguid: podcast1.guid, podcast: podcast1.title, publicationDate: pubDate3),
      ];

      await persistenceService.savePodcast(podcast1);
      await persistenceService.savePodcast(podcast2);
      await persistenceService.savePodcast(podcast3);

      var episode1 = await persistenceService.findEpisodeByGuid('EP001');
      var episode2 = await persistenceService.findEpisodeByGuid('EP002');

      expect(true, episode1 == podcast1.episodes[0]);
      expect(true, episode2 == podcast1.episodes[1]);

      episode1.downloadPercentage = 100;
      episode1.downloadState = DownloadState.downloaded;

      episode2.downloadPercentage = 100;
      episode2.downloadState = DownloadState.downloaded;

      await persistenceService.saveEpisode(episode1);
      await persistenceService.saveEpisode(episode2);

      var downloads = await persistenceService.findDownloads();

      expect(true, listEquals(downloads, <Episode>[episode2, episode1]));

      await persistenceService.deleteEpisode(episode1);

      downloads = await persistenceService.findDownloads();

      expect(true, listEquals(downloads, <Episode>[episode2]));
    });

    test('Subscribe after downloading episodes', () async {
      var pubDate5 = DateTime.now();
      var pubDate4 = DateTime.now().subtract(Duration(days: 1));
      var pubDate3 = DateTime.now().subtract(Duration(days: 2));
      var pubDate2 = DateTime.now().subtract(Duration(days: 3));
      var pubDate1 = DateTime.now().subtract(Duration(days: 4));

      podcast1.episodes = <Episode>[
        Episode(
            guid: 'EP001',
            title: 'Episode 1',
            pguid: podcast1.guid,
            podcast: podcast1.title,
            publicationDate: pubDate1,
            downloadPercentage: 0),
        Episode(
            guid: 'EP002',
            title: 'Episode 2',
            pguid: podcast1.guid,
            podcast: podcast1.title,
            publicationDate: pubDate2,
            downloadPercentage: 0),
        Episode(
            guid: 'EP005',
            title: 'Episode 5',
            pguid: podcast1.guid,
            podcast: podcast1.title,
            publicationDate: pubDate5,
            downloadPercentage: 0),
        Episode(
            guid: 'EP004',
            title: 'Episode 4',
            pguid: podcast1.guid,
            podcast: podcast1.title,
            publicationDate: pubDate4,
            downloadPercentage: 0),
        Episode(
            guid: 'EP003',
            title: 'Episode 3',
            pguid: podcast1.guid,
            podcast: podcast1.title,
            publicationDate: pubDate3,
            downloadPercentage: 0),
      ];

      var episode2 = Episode(
          guid: 'EP002',
          title: 'Episode 2',
          pguid: podcast1.guid,
          podcast: podcast1.title,
          publicationDate: pubDate2,
          downloadPercentage: 100);

      var episode5 = Episode(
          guid: 'EP005',
          title: 'Episode 5',
          pguid: podcast1.guid,
          podcast: podcast1.title,
          publicationDate: pubDate5,
          downloadPercentage: 100);

      // Save the downloaded episodes
      await persistenceService.saveEpisode(episode2);
      await persistenceService.saveEpisode(episode5);

      // Save the podcasts.
      await persistenceService.savePodcast(podcast1);
      await persistenceService.savePodcast(podcast2);
      await persistenceService.savePodcast(podcast3);

      // Fetch podcast1. Episodes should match.
      var p = await persistenceService.findPodcastByGuid(podcast1.guid);

      // Episodes 2 and 5 will be the saved episodes rather than
      // the blank episodes.
      var ep1 = p.episodes.firstWhere((e) => e.guid == 'EP001');
      var ep2 = p.episodes.firstWhere((e) => e.guid == 'EP002');
      var ep3 = p.episodes.firstWhere((e) => e.guid == 'EP003');
      var ep4 = p.episodes.firstWhere((e) => e.guid == 'EP004');
      var ep5 = p.episodes.firstWhere((e) => e.guid == 'EP005');

      expect(true, ep1.downloadPercentage == 0);
      expect(true, ep2.downloadPercentage == 100);
      expect(true, ep3.downloadPercentage == 0);
      expect(true, ep4.downloadPercentage == 0);
      expect(true, ep5.downloadPercentage == 100);
    });

    test('Fetch downloads for podcast', () async {
      var pubDate5 = DateTime.now();
      var pubDate4 = DateTime.now().subtract(Duration(days: 1));
      var pubDate3 = DateTime.now().subtract(Duration(days: 2));
      var pubDate2 = DateTime.now().subtract(Duration(days: 3));
      var pubDate1 = DateTime.now().subtract(Duration(days: 4));

      podcast1.episodes = <Episode>[
        Episode(
            guid: 'EP001',
            title: 'Episode 1',
            pguid: podcast1.guid,
            podcast: podcast1.title,
            publicationDate: pubDate1,
            downloadPercentage: 0),
        Episode(
            guid: 'EP002',
            title: 'Episode 2',
            pguid: podcast1.guid,
            podcast: podcast1.title,
            publicationDate: pubDate2,
            downloadPercentage: 0),
        Episode(
            guid: 'EP005',
            title: 'Episode 5',
            pguid: podcast1.guid,
            podcast: podcast1.title,
            publicationDate: pubDate5,
            downloadPercentage: 0),
        Episode(
            guid: 'EP004',
            title: 'Episode 4',
            pguid: podcast1.guid,
            podcast: podcast1.title,
            publicationDate: pubDate4,
            downloadPercentage: 0),
        Episode(
            guid: 'EP003',
            title: 'Episode 3',
            pguid: podcast1.guid,
            podcast: podcast1.title,
            publicationDate: pubDate3,
            downloadPercentage: 0),
      ];

      var episode2 = Episode(
          guid: 'EP002',
          title: 'Episode 2',
          pguid: podcast1.guid,
          podcast: podcast1.title,
          publicationDate: pubDate2,
          downloadPercentage: 100);

      var episode5 = Episode(
          guid: 'EP005',
          title: 'Episode 5',
          pguid: podcast1.guid,
          podcast: podcast1.title,
          publicationDate: pubDate5,
          downloadPercentage: 100);

      // Save the downloaded episodes
      await persistenceService.saveEpisode(episode2);
      await persistenceService.saveEpisode(episode5);

      // Save the podcasts.
      await persistenceService.savePodcast(podcast1);
      await persistenceService.savePodcast(podcast2);
      await persistenceService.savePodcast(podcast3);

      var pd1 = await persistenceService.findDownloadsByPodcastGuid(podcast1.guid);
      var pd2 = await persistenceService.findDownloadsByPodcastGuid(podcast2.guid);

      expect(true, listEquals(pd1, <Episode>[episode5, episode2]));
      expect(true, listEquals(pd2, <Episode>[]));
    });

    test('Fetch downloads by task ID', () async {
      var pubDate5 = DateTime.now();
      var pubDate4 = DateTime.now().subtract(Duration(days: 1));
      var pubDate3 = DateTime.now().subtract(Duration(days: 2));
      var pubDate2 = DateTime.now().subtract(Duration(days: 3));
      var pubDate1 = DateTime.now().subtract(Duration(days: 4));

      var tid1 = 'AAAA-BBBB-CCCC-DDDD-1000';
      var tid2 = 'AAAA-BBBB-CCCC-DDDD-2000';

      podcast1.episodes = <Episode>[
        Episode(
            guid: 'EP001',
            title: 'Episode 1',
            pguid: podcast1.guid,
            podcast: podcast1.title,
            publicationDate: pubDate1,
            downloadState: DownloadState.none,
            downloadPercentage: 0),
        Episode(
            guid: 'EP002',
            title: 'Episode 2',
            pguid: podcast1.guid,
            podcast: podcast1.title,
            publicationDate: pubDate2,
            downloadState: DownloadState.downloaded,
            downloadPercentage: 100),
        Episode(
            guid: 'EP005',
            title: 'Episode 5',
            pguid: podcast1.guid,
            podcast: podcast1.title,
            publicationDate: pubDate5,
            downloadState: DownloadState.downloading,
            downloadPercentage: 50),
        Episode(
            guid: 'EP004',
            title: 'Episode 4',
            pguid: podcast1.guid,
            podcast: podcast1.title,
            publicationDate: pubDate4,
            downloadState: DownloadState.none,
            downloadPercentage: 0),
        Episode(
            guid: 'EP003',
            title: 'Episode 3',
            pguid: podcast1.guid,
            podcast: podcast1.title,
            publicationDate: pubDate3,
            downloadState: DownloadState.none,
            downloadPercentage: 0),
      ];

      // Save the podcasts.
      await persistenceService.savePodcast(podcast1);

      var noDownload = await persistenceService.findEpisodeByTaskId(tid1);

      expect(noDownload, null);

      var e1 = podcast1.episodes.firstWhere((e) => e.guid == 'EP002');
      var e2 = podcast1.episodes.firstWhere((e) => e.guid == 'EP005');

      e1.downloadTaskId = tid1;
      e2.downloadTaskId = tid2;

      await persistenceService.saveEpisode(e1);
      await persistenceService.saveEpisode(e2);

      var episode1 = await persistenceService.findEpisodeByTaskId(tid1);

      expect(episode1.downloadPercentage, 100);

      var episode2 = await persistenceService.findEpisodeByTaskId(tid2);

      expect(episode2.downloadPercentage, 50);
    });
  });
}
