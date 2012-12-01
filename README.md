# CGManager
## Manager class for Apple GameCenter that makes life easier

CGManager helps you manage the Game Center aspect of your game. It makes it easy to report and keep track of high scores and achievements for different players.

## Features

- Separate profile for each player
- Local profile if Game Center is unsupported or nobody is logged on to Game Center
- Scores and achievements saved if no internet connection available or error occurred while reporting to Game Center
- Synchronization of Game Center data on first run
- Encryption of data
- ARC support

## Demo
Open `CGManagerDemo.xcodeproj`, setup bundle identifier for app with Game Center support and run it.

## Installation

1. Add the `GameKit` and `SystemConfiguration` frameworks to your Xcode project
2. Add the following files to your Xcode project:
 - CGManager.h  
 - CGManager.m
 - NSDataAES256.h
 - NSDataAES256.m
3. Open the `CGManager.h` file and change the `kCGManagerKey` constant to the secret key you want to use for encryption/decryption
4. Import the `CGManager.h` file
5. Enjoy

##Usage

###Initialize CGManager
You should initialize CGManager when your app is launched preferably in

<pre>
    - (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions 
</pre>

by calling

<pre>
    [CGManager sharedManager];
</pre>

This checks if Game Center is supported in the current device, authenticates the player and synchronizes scores and achievements from Game Center if its being run for the first time.

###Check Game Center Support
To check for Game Center support you can call

<pre>
    [[CGManager sharedManager] isGameCenterAvailable];
</pre>


###Report Score
To report a score to Game Center, call

<pre>
    [[CGManager sharedManager] saveAndReportScore:1000
                                              leaderboard:@"HighScores"];
</pre>

This method saves the score locally as well.

###Report Achievement
To report an achievement to Game Center, call

<pre>
    [[CGManager sharedManager] saveAndReportAchievement:@"1000Points"
                                                percentComplete:50];
</pre>

This method saves the achievement progress locally as well.

###Get High Scores
To get the high scores for the current player, you can call

<pre>
    //Array of leaderboard ID's to get high scores for
    NSArray *leaderboardIDs = [NSArray arrayWithObjects:@"Leaderboard1", @"Leaderboard2", nil];

    //Returns a dictionary with leaderboard ID's as keys and high scores as values
    [[CGManager defaultManager] highScoreForLeaderboards:leaderboardIDs];
</pre>

###Get Achievement Progress
To get achievement progress for the current player, you can call

<pre>
    //Array of achievement ID's to get progress for
    NSArray *achievementIDs = [NSArray arrayWithObjects:@"Achievement1", @"Achievement2", nil];

    //Returns a dictionary with achievement ID's as keys and progress as values
    [[CGManager defaultManager] progressForAchievements:achievementIDs];
</pre>

###Notifications
Notifications are posted at certain events mentioned below. The `userInfo` dictionary contains an error string for the key `error` if an error occured.

1. kCGManagerAvailabilityNotification - When unsupported devices attempt to authenticate the player, the `isGameCenterAvailable` property is set to `NO`
2. kCGManagerReportScoreNotification - When a score is reported to Game Center
3. kCGManagerReportAchievementNotification - When an achievement is reported to Game Center
4. kCGManagerResetAchievementNotification - When achievements are reset

###ARC support

CGManager uses ARC.
If you are using CGManager in your non-arc project, you will need to set a -fobjc-arc compiler flag on all of the CGManagers source files.
To set a compiler flag in Xcode, go to your active target and select the "Build Phases" tab. Now select all CGManager source files, press Enter, insert -fobjc-arc and then "Done" to disable ARC for CGManager.

## Contact

Val Pauloff

- http://about.me/symorium
- http://twitter.com/symorium
- symorium@gmail.com

## License

CGManager is available under the MIT license. See the LICENSE file for more info.