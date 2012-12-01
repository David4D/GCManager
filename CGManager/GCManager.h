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

// Notifications names
#define kGCManagerAvailabilityNotification @"GCManagerAvailabilityNotification"
#define kGCManagerReportScoreNotification @"GCManagerReportScoreNotification"
#define kGCManagerReportAchievementNotification @"GCManagerReportAchievementNotification"
#define kGCManagerResetAchievementNotification @"GCManagerResetAchievementNotification"

#import <Foundation/Foundation.h>
#import <GameKit/GameKit.h>
#import "NSDataAES256.h"

@interface GCManager : NSObject
{
    NSMutableArray * leaderboards;
}

// Use this property to check if Game Center is available and supported on the current device.
@property (nonatomic, readonly) BOOL isGameCenterAvailable;

// Returns the shared instance of GCManager.
+ (GCManager *)sharedManager;

// Synchronizes local player data with Game Center data.
- (void)syncGameCenter;

// Saves score locally and reports it to Game Center. If error occurs, score is saved to be submitted later.
- (void)saveAndReportScore:(int)score leaderboard:(NSString *)identifier;

// Saves achievement locally and reports it to Game Center. If error occurs, achievement is saved to be submitted later.
- (void)saveAndReportAchievement:(NSString *)identifier percentComplete:(double)percentComplete;

// Reports scores and achievements which could not be reported earlier.
- (void)reportSavedScoresAndAchievements;

// Saves score to be submitted later.
- (void)saveScoreToReportLater:(GKScore *)score;

// Saves achievement to be submitted later.
- (void)saveAchievementToReportLater:(NSString *)identifier percentComplete:(double)percentComplete;

// Returns local player's high score for specified leaderboard.
- (int)highScoreForLeaderboard:(NSString *)identifier;

// Returns local player's high scores for multiple leaderboards.
- (NSDictionary *)highScoreForLeaderboards:(NSArray *)identifiers;

// Returns local player's percent completed for specified achievement.
- (double)progressForAchievement:(NSString *)identifier;

// Returns local player's percent completed for multiple achievements.
- (NSDictionary *)progressForAchievements:(NSArray *)identifiers;

// Resets local player's achievements
- (void)resetAchievements;

// Returns currently authenticated local player. If no player is authenticated, "unknownPlayer" is returned.
- (NSString *)localPlayerId;

// GKLeaderboardViewController with scope and delegate
- (GKLeaderboardViewController *) gkLeaderBoardControllerWithTimeScope: (GKLeaderboardTimeScope) scope
                                                    delegate: (id<GKLeaderboardViewControllerDelegate>) delegate;

// GKAchievementViewController with delegate
- (GKAchievementViewController *) gkAchievementControllerWithDelegate: (id<GKAchievementViewControllerDelegate>) delegate;

@end