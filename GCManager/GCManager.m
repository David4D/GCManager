// CGManager
//
// Copyright (c) 2011 Val Pauloff (http://about.me/symorium)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE

#import "GCManager.h"

// Change this value to your own secret key
#define kGCManagerKey [@"MyKey" dataUsingEncoding:NSUTF8StringEncoding]

// What folder GCManager stores data
#define kCGManagerWorkFolder [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex: 0]

// What file GCManager stores data
#define kGCManagerDataFile @"GCManager.plist"

// Full path to GCManager data
#define kGCManagerDataPath [kCGManagerWorkFolder stringByAppendingPathComponent:kGCManagerDataFile]

#pragma mark - Game Center Manager shared instance

@implementation GCManager

+ (GCManager *)sharedManager
{
    static GCManager * _sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedManager = [GCManager new];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if(![fileManager fileExistsAtPath:kGCManagerDataPath]) {
            NSMutableDictionary *dict = [NSMutableDictionary dictionary];
            NSData *saveData = [[NSKeyedArchiver archivedDataWithRootObject:dict] encryptedWithKey:kGCManagerKey];
            [saveData writeToFile:kGCManagerDataPath atomically:YES];
        }
        [_sharedManager initGameCenter];
    });
    
    return _sharedManager;
}

#pragma mark - Methods

- (void)initGameCenter
{
    // Check for presence of GKLocalPlayer class.
    BOOL localPlayerClassAvailable = (NSClassFromString(@"GKLocalPlayer")) != nil;
    
    // The device must be running iOS 4.1 or later.
    NSString *reqSysVer = @"4.1";
    NSString *currSysVer = [[UIDevice currentDevice] systemVersion];
    BOOL osVersionSupported = ([currSysVer compare:reqSysVer options:NSNumericSearch] != NSOrderedAscending);
    
    BOOL isGameCenterAPIAvailable = (localPlayerClassAvailable && osVersionSupported);
    
    if(isGameCenterAPIAvailable) {
        _isGameCenterAvailable = YES;
       GKLocalPlayer *localPlayer = [GKLocalPlayer localPlayer];
       localPlayer.authenticateHandler = ^(UIViewController *viewController, NSError *error) {
          if(error == nil) {
             if(![[NSUserDefaults standardUserDefaults] boolForKey:[@"scoresSynced" stringByAppendingString:[[GCManager sharedManager] localPlayerId]]] ||
                ![[NSUserDefaults standardUserDefaults] boolForKey:[@"achievementsSynced" stringByAppendingString:[[GCManager sharedManager] localPlayerId]]]) {
                [[GCManager sharedManager] syncGameCenter];
             }
             else {
                [[GCManager sharedManager] reportSavedScoresAndAchievements];
             }
          }
          else {
             if(error.code == GKErrorNotSupported) {
                _isGameCenterAvailable = NO;
             }
          }
          NSMutableDictionary * userInfo = [NSMutableDictionary new];
          if (error) [userInfo setObject:error forKey:@"error"];
          [[NSNotificationCenter defaultCenter] postNotificationName:kGCManagerAvailabilityNotification
                                                              object:[GCManager sharedManager]
                                                            userInfo:userInfo];
       };
    }
}

- (void)syncGameCenter
{
    if(_isGameCenterAvailable) {
        if(![[NSUserDefaults standardUserDefaults] boolForKey:[@"scoresSynced" stringByAppendingString:[[GCManager sharedManager] localPlayerId]]]) {
            if(leaderboards == nil) {
                [GKLeaderboard loadCategoriesWithCompletionHandler:^(NSArray *categories, NSArray *titles, NSError *error) {
                    if(error == nil) {
                        leaderboards = [[NSMutableArray alloc] initWithArray:categories];
                        [[GCManager sharedManager] syncGameCenter];
                    }
                }];
                return;
            }
            
            if(leaderboards.count > 0) {
                GKLeaderboard *leaderboardRequest = [[GKLeaderboard alloc] initWithPlayerIDs:[NSArray arrayWithObject:[[GCManager sharedManager] localPlayerId]]];
                [leaderboardRequest setCategory:[leaderboards objectAtIndex:0]];
                [leaderboardRequest loadScoresWithCompletionHandler:^(NSArray *scores, NSError *error) {
                    if(error == nil) {
                        if(scores.count > 0) {
                            NSData *GCManagerData = [[NSData dataWithContentsOfFile:kGCManagerDataPath] decryptedWithKey:kGCManagerKey];
                            NSMutableDictionary *plistDict = [NSKeyedUnarchiver unarchiveObjectWithData:GCManagerData];
                            NSMutableDictionary *playerDict = [plistDict objectForKey:[[GCManager sharedManager] localPlayerId]];
                            if(playerDict == nil) {
                                playerDict = [NSMutableDictionary dictionary];
                            }
                            int savedHighScoreValue = 0;
                            NSNumber *savedHighScore = [playerDict objectForKey:leaderboardRequest.localPlayerScore.category];
                            if(savedHighScore != nil) {
                                savedHighScoreValue = [savedHighScore intValue];
                            }
                            [playerDict setObject:[NSNumber numberWithInt:MAX(leaderboardRequest.localPlayerScore.value, savedHighScoreValue)] forKey:leaderboardRequest.localPlayerScore.category];
                            [plistDict setObject:playerDict forKey:[[GCManager sharedManager] localPlayerId]];
                            NSData *saveData = [[NSKeyedArchiver archivedDataWithRootObject:plistDict] encryptedWithKey:kGCManagerKey];
                            [saveData writeToFile:kGCManagerDataPath atomically:YES];
                        }
                        
                        [leaderboards removeObjectAtIndex:0];
                        [[GCManager sharedManager] syncGameCenter];
                    }
                }];
            }
            else {
                [[NSUserDefaults standardUserDefaults] setBool:YES forKey:[@"scoresSynced" stringByAppendingString:[[GCManager sharedManager] localPlayerId]]];
                [[GCManager sharedManager] syncGameCenter];
            }
        }
        else if(![[NSUserDefaults standardUserDefaults] boolForKey:[@"achievementsSynced" stringByAppendingString:[[GCManager sharedManager] localPlayerId]]]) {
            [GKAchievement loadAchievementsWithCompletionHandler:^(NSArray *achievements, NSError *error) {
                if(error == nil) {
                    if(achievements.count > 0) {
                        NSData *GCManagerData = [[NSData dataWithContentsOfFile:kGCManagerDataPath] decryptedWithKey:kGCManagerKey];
                        NSMutableDictionary *plistDict = [NSKeyedUnarchiver unarchiveObjectWithData:GCManagerData];
                        NSMutableDictionary *playerDict = [plistDict objectForKey:[[GCManager sharedManager] localPlayerId]];
                        if(playerDict == nil) {
                            playerDict = [NSMutableDictionary dictionary];
                        }
                        for(GKAchievement *achievement in achievements) {
                            [playerDict setObject:[NSNumber numberWithDouble:achievement.percentComplete] forKey:achievement.identifier];
                        }
                        [plistDict setObject:playerDict forKey:[[GCManager sharedManager] localPlayerId]];
                        NSData *saveData = [[NSKeyedArchiver archivedDataWithRootObject:plistDict] encryptedWithKey:kGCManagerKey];
                        [saveData writeToFile:kGCManagerDataPath atomically:YES];
                    }
                    
                    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:[@"achievementsSynced" stringByAppendingString:[[GCManager sharedManager] localPlayerId]]];
                    [[GCManager sharedManager] syncGameCenter];
                }
            }];
        }
    }
}

- (void)saveAndReportScore:(int)score leaderboard:(NSString *)identifier
{
    if (!_isGameCenterAvailable)
        return;
    NSData *GCManagerData = [[NSData dataWithContentsOfFile:kGCManagerDataPath] decryptedWithKey:kGCManagerKey];
    NSMutableDictionary *plistDict = [NSKeyedUnarchiver unarchiveObjectWithData:GCManagerData];
    NSMutableDictionary *playerDict = [plistDict objectForKey:[[GCManager sharedManager] localPlayerId]];
    if(playerDict == nil) {
        playerDict = [NSMutableDictionary dictionary];
    }
    NSNumber *savedHighScore = [playerDict objectForKey:identifier];
    if(savedHighScore == nil) {
        savedHighScore = [NSNumber numberWithInt:0];
    }
    int savedHighScoreValue = [savedHighScore intValue];
    if(score > savedHighScoreValue) {
        [playerDict setObject:[NSNumber numberWithInt:score] forKey:identifier];
        [plistDict setObject:playerDict forKey:[[GCManager sharedManager] localPlayerId]];
        NSData *saveData = [[NSKeyedArchiver archivedDataWithRootObject:plistDict] encryptedWithKey:kGCManagerKey];
        [saveData writeToFile:kGCManagerDataPath atomically:YES];
    }
    
    if([[GCManager sharedManager] isGameCenterAvailable]) {
        if([GKLocalPlayer localPlayer].authenticated) {
            GKScore *gkScore = [[GKScore alloc] initWithCategory:identifier];
            gkScore.value = score;
            [gkScore reportScoreWithCompletionHandler:^(NSError *error) {
                NSDictionary *dict = nil;
                if(error == nil) {
                    dict = [NSDictionary dictionary];
                }
                else {
                    dict = [NSDictionary dictionaryWithObject:error.localizedDescription forKey:@"error"];
                    [[GCManager sharedManager] saveScoreToReportLater:gkScore];
                }
                [[NSNotificationCenter defaultCenter] postNotificationName:kGCManagerReportScoreNotification
                                                                    object:[GCManager sharedManager]
                                                                  userInfo:dict];
            }];
        }
    }
}

- (void)saveAndReportAchievement:(NSString *)identifier percentComplete:(double)percentComplete
{
    if (!_isGameCenterAvailable)
        return;
    NSData *GCManagerData = [[NSData dataWithContentsOfFile:kGCManagerDataPath] decryptedWithKey:kGCManagerKey];
    NSMutableDictionary *plistDict = [NSKeyedUnarchiver unarchiveObjectWithData:GCManagerData];
    NSMutableDictionary *playerDict = [plistDict objectForKey:[[GCManager sharedManager] localPlayerId]];
    if(playerDict == nil) {
        playerDict = [NSMutableDictionary dictionary];
    }
    NSNumber *savedPercentComplete = [playerDict objectForKey:identifier];
    if(savedPercentComplete == nil) {
        savedPercentComplete = [NSNumber numberWithDouble:0];
    }
    double savedPercentCompleteValue = [savedPercentComplete doubleValue];
    if(percentComplete > savedPercentCompleteValue) {
        [playerDict setObject:[NSNumber numberWithDouble:percentComplete] forKey:identifier];
        [plistDict setObject:playerDict forKey:[[GCManager sharedManager] localPlayerId]];
        NSData *saveData = [[NSKeyedArchiver archivedDataWithRootObject:plistDict] encryptedWithKey:kGCManagerKey];
        [saveData writeToFile:kGCManagerDataPath atomically:YES];
    }
    
    if([[GCManager sharedManager] isGameCenterAvailable]) {
        if([GKLocalPlayer localPlayer].authenticated) {
            GKAchievement *achievement = [[GKAchievement alloc] initWithIdentifier:identifier];
            achievement.percentComplete = percentComplete;
            [achievement reportAchievementWithCompletionHandler:^(NSError *error) {
                NSDictionary *dict = nil;
                if(error == nil) {
                    dict = [NSDictionary dictionary];
                }
                else {
                    dict = [NSDictionary dictionaryWithObject:error.localizedDescription forKey:@"error"];
                    [[GCManager sharedManager] saveAchievementToReportLater:identifier percentComplete:percentComplete];
                }
                [[NSNotificationCenter defaultCenter] postNotificationName:kGCManagerReportAchievementNotification
                                                                    object:[GCManager sharedManager]
                                                                  userInfo:dict];
            }];
        }
    }
}

- (void)saveScoreToReportLater:(GKScore *)score
{
    if (!_isGameCenterAvailable)
        return;
    NSData *scoreData = [NSKeyedArchiver archivedDataWithRootObject:score];
    NSData *GCManagerData = [[NSData dataWithContentsOfFile:kGCManagerDataPath] decryptedWithKey:kGCManagerKey];
    NSMutableDictionary *plistDict = [NSKeyedUnarchiver unarchiveObjectWithData:GCManagerData];
    NSMutableArray *savedScores = [plistDict objectForKey:@"SavedScores"];
    if(savedScores != nil) {
        [savedScores addObject:scoreData];
    }
    else {
        savedScores = [NSMutableArray arrayWithObject:scoreData];
    }
    [plistDict setObject:savedScores forKey:@"SavedScores"];
    NSData *saveData = [[NSKeyedArchiver archivedDataWithRootObject:plistDict] encryptedWithKey:kGCManagerKey];
    [saveData writeToFile:kGCManagerDataPath atomically:YES];
}

- (void)saveAchievementToReportLater:(NSString *)identifier percentComplete:(double)percentComplete
{
    if (!_isGameCenterAvailable)
        return;
    NSData *GCManagerData = [[NSData dataWithContentsOfFile:kGCManagerDataPath] decryptedWithKey:kGCManagerKey];
    NSMutableDictionary *plistDict = [NSKeyedUnarchiver unarchiveObjectWithData:GCManagerData];
    NSMutableDictionary *playerDict = [plistDict objectForKey:[[GCManager sharedManager] localPlayerId]];
    if(playerDict != nil) {
        NSMutableDictionary *savedAchievements = [playerDict objectForKey:@"SavedAchievements"];
        if(savedAchievements != nil) {
            double savedPercentCompleteValue = 0;
            NSNumber *savedPercentComplete = [savedAchievements objectForKey:identifier];
            if(savedPercentComplete != nil) {
                savedPercentCompleteValue = [savedPercentComplete doubleValue];
            }
            savedPercentComplete = [NSNumber numberWithDouble:percentComplete + savedPercentCompleteValue];
            [savedAchievements setObject:savedPercentComplete forKey:identifier];
        }
        else {
            savedAchievements = [NSMutableDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithDouble:percentComplete], identifier, nil];
            [playerDict setObject:savedAchievements forKey:@"SavedAchievements"];
        }
    }
    else {
        NSMutableDictionary *savedAchievements = [NSMutableDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithDouble:percentComplete], identifier, nil];
        playerDict = [NSMutableDictionary dictionaryWithObjectsAndKeys:savedAchievements, @"SavedAchievements", nil];                    
    }
    [plistDict setObject:playerDict forKey:[[GCManager sharedManager] localPlayerId]];
    NSData *saveData = [[NSKeyedArchiver archivedDataWithRootObject:plistDict] encryptedWithKey:kGCManagerKey];
    [saveData writeToFile:kGCManagerDataPath atomically:YES];    
}

- (int)highScoreForLeaderboard:(NSString *)identifier
{
    if (!_isGameCenterAvailable)
        return -1;
    NSData *GCManagerData = [[NSData dataWithContentsOfFile:kGCManagerDataPath] decryptedWithKey:kGCManagerKey];
    NSMutableDictionary *plistDict = [NSKeyedUnarchiver unarchiveObjectWithData:GCManagerData];
    NSMutableDictionary *playerDict = [plistDict objectForKey:[[GCManager sharedManager] localPlayerId]];
    if(playerDict != nil) {
        NSNumber *savedHighScore = [playerDict objectForKey:identifier];
        if(savedHighScore != nil) {
            return [savedHighScore intValue];
        }
    }
    return 0;
}

- (NSDictionary *)highScoreForLeaderboards:(NSArray *)identifiers
{
    if (!_isGameCenterAvailable)
        return nil;
    NSData *GCManagerData = [[NSData dataWithContentsOfFile:kGCManagerDataPath] decryptedWithKey:kGCManagerKey];
    NSMutableDictionary *plistDict = [NSKeyedUnarchiver unarchiveObjectWithData:GCManagerData];
    NSMutableDictionary *playerDict = [plistDict objectForKey:[[GCManager sharedManager] localPlayerId]];
    NSMutableDictionary *highScores = [[NSMutableDictionary alloc] initWithCapacity:identifiers.count];
    for(NSString *identifier in identifiers) {
        if(playerDict != nil) {
            NSNumber *savedHighScore = [playerDict objectForKey:identifier];
            if(savedHighScore != nil) {
                [highScores setObject:[NSNumber numberWithInt:[savedHighScore intValue]] forKey:identifier];
                continue;
            }
        }
        [highScores setObject:[NSNumber numberWithInt:0] forKey:identifier];
    }
    
    NSDictionary *highScoreDict = [NSDictionary dictionaryWithDictionary:highScores];
    
    return highScoreDict;
}

- (double)progressForAchievement:(NSString *)identifier
{
    if (!_isGameCenterAvailable)
        return -1;
    NSData *GCManagerData = [[NSData dataWithContentsOfFile:kGCManagerDataPath] decryptedWithKey:kGCManagerKey];
    NSMutableDictionary *plistDict = [NSKeyedUnarchiver unarchiveObjectWithData:GCManagerData];
    NSMutableDictionary *playerDict = [plistDict objectForKey:[[GCManager sharedManager] localPlayerId]];
    if(playerDict != nil) {
        NSNumber *savedPercentComplete = [playerDict objectForKey:identifier];
        if(savedPercentComplete != nil) {
            return [savedPercentComplete doubleValue];
        }
    }
    return 0;
}

- (NSDictionary *)progressForAchievements:(NSArray *)identifiers
{
    if (!_isGameCenterAvailable)
        return nil;
    NSData *GCManagerData = [[NSData dataWithContentsOfFile:kGCManagerDataPath] decryptedWithKey:kGCManagerKey];
    NSMutableDictionary *plistDict = [NSKeyedUnarchiver unarchiveObjectWithData:GCManagerData];
    NSMutableDictionary *playerDict = [plistDict objectForKey:[[GCManager sharedManager] localPlayerId]];
    NSMutableDictionary *percent = [[NSMutableDictionary alloc] initWithCapacity:identifiers.count];
    for(NSString *identifier in identifiers) {
        if(playerDict != nil) {
            NSNumber *savedPercentComplete = [playerDict objectForKey:identifier];
            if(savedPercentComplete != nil) {
                [percent setObject:[NSNumber numberWithDouble:[savedPercentComplete doubleValue]] forKey:identifier];
                continue;
            }
        }
        [percent setObject:[NSNumber numberWithDouble:0] forKey:identifier];
    }
    
    NSDictionary *percentDict = [NSDictionary dictionaryWithDictionary:percent];
    
    return percentDict;
}

- (void)reportSavedScoresAndAchievements
{
    if(_isGameCenterAvailable) {
        GKScore *gkScore = nil;
        
        NSData *GCManagerData = [[NSData dataWithContentsOfFile:kGCManagerDataPath] decryptedWithKey:kGCManagerKey];
        NSMutableDictionary *plistDict = [NSKeyedUnarchiver unarchiveObjectWithData:GCManagerData];
        NSMutableArray *savedScores = [plistDict objectForKey:@"SavedScores"];
        if(savedScores != nil) {
            if(savedScores.count > 0) {
                gkScore = [NSKeyedUnarchiver unarchiveObjectWithData:[savedScores objectAtIndex:0]];
                [savedScores removeObjectAtIndex:0];
                [plistDict setObject:savedScores forKey:@"SavedScores"];
                NSData *saveData = [[NSKeyedArchiver archivedDataWithRootObject:plistDict] encryptedWithKey:kGCManagerKey];
                [saveData writeToFile:kGCManagerDataPath atomically:YES];
            }
        }
        
        if(gkScore != nil) {            
            [gkScore reportScoreWithCompletionHandler:^(NSError *error) {
                if(error == nil) {                    
                    [[GCManager sharedManager] reportSavedScoresAndAchievements];
                }
                else {
                    [[GCManager sharedManager] saveScoreToReportLater:gkScore];
                }
            }];
        }
        else {
            if([GKLocalPlayer localPlayer].authenticated) {
                NSString *identifier = nil;
                double percentComplete = 0;
                
                NSData *GCManagerData = [[NSData dataWithContentsOfFile:kGCManagerDataPath] decryptedWithKey:kGCManagerKey];
                NSMutableDictionary *plistDict = [NSKeyedUnarchiver unarchiveObjectWithData:GCManagerData];
                NSMutableDictionary *playerDict = [plistDict objectForKey:[[GCManager sharedManager] localPlayerId]];
                if(playerDict != nil) {
                    NSMutableDictionary *savedAchievements = [playerDict objectForKey:@"SavedAchievements"];
                    if(savedAchievements != nil) {
                        if(savedAchievements.count > 0) {
                            identifier = [[savedAchievements allKeys] objectAtIndex:0];
                            percentComplete = [[savedAchievements objectForKey:identifier] doubleValue];
                            [savedAchievements removeObjectForKey:identifier];
                            [playerDict setObject:savedAchievements forKey:@"SavedAchievements"];
                            [plistDict setObject:playerDict forKey:[[GCManager sharedManager] localPlayerId]];
                            NSData *saveData = [[NSKeyedArchiver archivedDataWithRootObject:plistDict] encryptedWithKey:kGCManagerKey];
                            [saveData writeToFile:kGCManagerDataPath atomically:YES];
                        }
                    }
                }
                
                if(identifier != nil) {
                    GKAchievement *achievement = [[GKAchievement alloc] initWithIdentifier:identifier];
                    achievement.percentComplete = percentComplete;
                    [achievement reportAchievementWithCompletionHandler:^(NSError *error) {
                        if(error == nil) {
                            [[GCManager sharedManager] reportSavedScoresAndAchievements];
                        }
                        else {
                            [[GCManager sharedManager] saveAchievementToReportLater:achievement.identifier percentComplete:achievement.percentComplete]; 
                        }
                    }];
                }
            }
        }
    }
}

- (void) resetAchievements
{
    if(_isGameCenterAvailable) {
        [GKAchievement resetAchievementsWithCompletionHandler:^(NSError *error) {
            NSDictionary *dict = nil;
            if(error == nil) {
                dict = [NSDictionary dictionary];
            }
            else {
                dict = [NSDictionary dictionaryWithObject:error forKey:@"error"];
            }
            [[NSNotificationCenter defaultCenter] postNotificationName:kGCManagerResetAchievementNotification
                                                                object:[GCManager sharedManager]
                                                              userInfo:dict];
        }];
    }
}

- (NSString *)localPlayerId
{
    if(_isGameCenterAvailable) {
        if([GKLocalPlayer localPlayer].authenticated) {
            return [GKLocalPlayer localPlayer].playerID;
        }
    }
    return @"unknownPlayer";
}

- (GKLeaderboardViewController *) gkLeaderBoardControllerWithTimeScope: (GKLeaderboardTimeScope) scope
                                                              category: (NSString *) category
                                                              delegate: (id<GKLeaderboardViewControllerDelegate>) delegate
{
    GKLeaderboardViewController * leaderboardViewController = [GKLeaderboardViewController new];
    leaderboardViewController.timeScope = GKLeaderboardTimeScopeAllTime;
    leaderboardViewController.leaderboardDelegate = delegate;
    leaderboardViewController.category = category;
    return leaderboardViewController;
}

- (GKAchievementViewController *) gkAchievementControllerWithDelegate: (id<GKAchievementViewControllerDelegate>) delegate
{
    GKAchievementViewController *achievementViewController = [GKAchievementViewController new];
    achievementViewController.achievementDelegate = delegate;
    return achievementViewController;
}

@end
