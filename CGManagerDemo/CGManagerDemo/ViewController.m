// CGManagerDemo
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

#import "ViewController.h"

#define LeaderBoardID @"leaderboard"
#define AchievementID @"1000Points"

@implementation ViewController

#pragma mark - View lifecycle

- (void) viewDidLoad
{
    [super viewDidLoad];
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear: animated];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(callback:)
                                                 name:kGCManagerAvailabilityNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(callback:)
                                                 name:kGCManagerReportScoreNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(callback:)
                                                 name:kGCManagerReportAchievementNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(callback:)
                                                 name:kGCManagerResetAchievementNotification object:nil];
}

- (void) viewWillDisappear:(BOOL)animated
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}

#pragma mark - IBActions

- (IBAction) reportScore {
    int score = (arc4random() % 1000);
    [[GCManager sharedManager] saveAndReportScore: score leaderboard: LeaderBoardID];
}

- (IBAction) reportAchievement {
    [[GCManager sharedManager] saveAndReportAchievement: AchievementID percentComplete:50];
}

- (IBAction) showLeaderboard {
    if([[GCManager sharedManager] isGameCenterAvailable]) {
        GKLeaderboardViewController * leaderboardViewController = [[GCManager sharedManager] gkLeaderBoardControllerWithTimeScope:GKLeaderboardTimeScopeAllTime category:LeaderBoardID delegate: self];
        if ([self respondsToSelector:@selector(presentViewController:animated:completion:)])
            [self presentViewController: leaderboardViewController animated: YES completion:^{}];
        else
            [self presentModalViewController:leaderboardViewController animated:YES];
    }
    else {
        label.text = @"Game Center unavailable";
    }
}

- (IBAction) showAchievements {
    if([[GCManager sharedManager] isGameCenterAvailable]) {
        GKAchievementViewController *achievementViewController = [[GCManager sharedManager] gkAchievementControllerWithDelegate:self];
        if ([self respondsToSelector:@selector(presentViewController:animated:completion:)])
            [self presentViewController: achievementViewController animated: YES completion:^{}];
        else
            [self presentModalViewController:achievementViewController animated:YES];
    }
    else {
        label.text = @"Game Center unavailable";
    }
}

- (IBAction) resetAchievements {
    [[GCManager sharedManager] resetAchievements];
}

#pragma mark - GKAchievementViewControllerDelegate methods

- (void)achievementViewControllerDidFinish:(GKAchievementViewController *)viewController {
    [self dismissModalViewControllerAnimated:YES];
}

#pragma mark - GKLeaderboardViewControllerDelegate methods
- (void) leaderboardViewControllerDidFinish:(GKLeaderboardViewController *)viewController {
    [self dismissModalViewControllerAnimated:YES];
}

#pragma mark - GCManager notifications handling

- (void)callback:(NSNotification *)notification {
    NSError * error = [notification.userInfo objectForKey: @"error"];
    if(error == nil) {
        label.text = @"Success";
    }
    else {
        label.text = [NSString stringWithFormat:@"Error: %@", error.localizedDescription];
    }
}
@end
