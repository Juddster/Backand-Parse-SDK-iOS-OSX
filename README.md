# Backand SDK for iOS/OS X/watchOS/tvOS

[![License][license-svg]][license-link]

This SDK has been forked from the Parse SDK. It has been modified to access Backand's backend service instead of the Parse backend. My intention is to maintain source level compatibility with the original Parse SDK and preserve as much functionality as possible. My goal is to minimize code changes for projects that are migrating from Parse to Backand.

This is a library that gives you access to the Backand cloud platform from your iOS or OS X app.
For the SDK documentation, for now, please refer to the original [Parse docs][Parse Docs].
For more information on Backand and its features, see [the website][Backand.com] and [getting started][docs].

## Getting Started

To use this SDK, head on over to the [releases][releases] page, and download the latest build.

###Migrating an existing project from Parse to Backand
1. Replace `Parse.framework` in your project with `Backand.framework` you downloaded above.
2. Throughout the project, replace `#import <Parse/*.h>` with `#import <Backand/*.h>`
3. **In swift projects**, In the bridging_header.h, `#import <Backand/Backand.h>` instead of `#import <Parse/Parse.h>`. and in the rest of the project replace `import Parse` with `import Backand`
At this point, if you build and run your app, everything should be the same as with the original Parse.framework. It is still running against Parse.com's backend and **everything should be fully functional**. The only difference you should see is a message in the debug console confirming that you are now using the Parse SDK for Backand.
4. In your app delegate, replace the call to `[Parse setApplicationId:clientKey:]` with a call to `[Parse setBackandAppName:andSignupToken:]`  (you can obtain these from your Backand app). (*in swift* call `Parse.setBackandAppName(“BACKAND-APP-NAME”, andSignupToken: "BACKAND-APP-SIGNUP-TOKEN”)` instead of `Parse.setApplicationId(PARSE_APP_ID, clientKey: PARSE_CLIENT_KEY)`)
Now your app is running against Backand.com's backend and you should expect some of the API calls to raise exceptions (e.g. Not Yet Implemented).

**Note:** You'll want to migrate your app/database from Parse.com to Backand.com. See [migration instructions][migration]

**Note:** Although a significant subset of the SDK is ready, certainly there are areas that are not yet working. For most of the scenarios that are not supported yet, an exception is raised so you can't miss it. please reffer to the [project status page][status page] for updated lists of what's ready and what's not. If you need portions of the SDK that are still not ready, please let me know as that will factor in on my prioritiesation.

###New projects
1. Add the frameworks `Backand` and `Bolts` that you downloaded above to your project.
2. Additionally, add the frameworks: `SystemConfiguration`, `AudioToolbox` & `libsqlite3`
3. In your AppDelegate `#import <Backand/Backand.h>` 
4. In your `application:didFinishLaunchingWithOptions:` add a call to `[Parse setBackandAppName:andSignupToken:]`  (you can obtain these from your Backand app).
5. You're all set. Run your app and you'll see in the debug console a message confirming that you are now using the Parse SDK for Backand.

Please refer to the original [Parse docs][Parse Docs] for further info.

**Note:** You'll need to create an app in the Backand UI as well as define the databse tables as needed for your app. Unlike Parse, Backand doesn't support building the schema on the fly.

###Other Installation Options

 - **[CocoaPods](https://cocoapods.org)**

  Add the following line to your Podfile:
  ```ruby
  pod 'Backand'
  ```
  Run `pod install`, and you should now have the latest parse release.
   

**Note:** If you are also using **ParseFacebookUtilsV4**, You'll need to replace that pod with the **BackandParseFacebookUtilsV4** pod. It is the exact same code. The only change is to make it depend on the Backand pod/framework. It is there only to get a project to build. But I don't expect it to work yet as I didn't touch the necessary APIs in the Backand pod.


 - **Compiling for yourself**

    If you want to manually compile the SDK, clone it locally, and run the following commands in the root directory of the repository:

        # To pull in extra dependencies (Bolts and OCMock)
        git submodule update --init --recursive

        # To install all the gems
        bundle install

        # Build & Package the Frameworks
        rake package:frameworks

    Compiled frameworks will be in 2 archives: `Backand-iOS.zip` and `Backand-OSX.zip` inside the `build/release` folder, and you can link them as you'd please.

 - **Using Parse as a sub-project**

    You can also include parse as a subproject inside of your application if you'd prefer, although we do not recommend this, as it will increase your indexing time significantly. To do so, just drag and drop the Parse.xcodeproj file into your workspace. Note that unit tests will be unavailable if you use Parse like this, as OCMock will be unable to be found.

## Dependencies

This SDK uses the following libraries as dependencies inside of Backand:

 - [Bolts][bolts-framework], for task management.
 - [OCMock][ocmock-framework], for unit testing.

 [Parse Docs]: https://parse.com/docs/ios/guide
 [Backand.com]: https://www.backand.com/
 [migration]: https://www.backand.com/parse-alternative/
 [docs]: http://docs.backand.com/en/latest/index.html
 [comparison]: https://www.backand.com/iOS-sdk-parse-comparison
 [ios SDK documentation]: http://docs.backand.com/en/latest/index.html
 [status page]: https://github.com/Juddster/Backand-Parse-SDK-iOS-OSX/wiki/Status
 [releases]: https://github.com/Juddster/Backand-Parse-SDK-iOS-OSX/releases

 [bolts-framework]: https://github.com/BoltsFramework/Bolts-iOS
 [ocmock-framework]: http://ocmock.org

 [license-svg]: https://img.shields.io/badge/license-BSD-lightgrey.svg
 [license-link]: https://github.com/ParsePlatform/Parse-SDK-iOS-OSX/blob/master/LICENSE

