# How To Adult - Project Completion Tasks

## Overview
This document catalogs all incomplete features, placeholder code, scaffolding, and stubs identified in the "How To Adult" iOS application. Each task includes detailed information about the required implementation, affected files, changes needed, and acceptance criteria.

## General Implementation Workflow

For each task in this document, follow this standardized workflow:

1. **IMPLEMENT** - Make the code changes described in the task
2. **TEST** - Verify the changes work correctly and meet acceptance criteria
3. **COMMIT** - Commit changes with a clear, descriptive commit message
4. **DOCUMENT** - Update relevant documentation to reflect the changes

---

## Table of Contents
1. [Core Content Implementation](#task-1-core-content-implementation)
2. [Laundry Feature Implementation](#task-2-laundry-feature-implementation)
3. [Core Data Model Definition](#task-3-core-data-model-definition)
4. [Production-Ready Error Handling](#task-4-production-ready-error-handling)
5. [Dynamic Cell Height Management](#task-5-dynamic-cell-height-management)
6. [Unit Test Implementation](#task-6-unit-test-implementation)
7. [UI Test Implementation](#task-7-ui-test-implementation)
8. [Project Documentation](#task-8-project-documentation)
9. [LICENSE File Completion](#task-9-license-file-completion)
10. [Cell Selection Handling](#task-10-cell-selection-handling)

---

## TASK 1: Core Content Implementation

### Feature Description
Replace the current placeholder prime number generation with actual "How To Adult" educational content. The app should display practical life skills topics (e.g., Laundry, Cooking, Budgeting, Job Interviews, etc.) instead of mathematical primes.

### Problem Statement
Currently, `HTADataManager` generates 168 prime numbers (0-1000) as placeholder data. This doesn't align with the app's purpose of teaching adult life skills.

### Affected Files
- `How To Adult/HTADataManager.h`
- `How To Adult/HTADataManager.m`
- `How To Adult/HTARowModel.h`
- `How To Adult/HTARowModel.m`
- `How To Adult/ViewController.m`

### Changes Needed

#### HTADataManager.m
1. Remove or refactor `calculatePrimes` method
2. Create a new method `loadAdultSkillsContent` that:
   - Defines adult life skill topics (Laundry, Cooking, Budgeting, Job Interviews, Taxes, Car Maintenance, First Aid, Grocery Shopping, Credit Cards, Apartment Hunting, etc.)
   - Creates appropriate `HTARowModel` or specialized model instances for each topic
   - Assigns meaningful titles, descriptions, and icons (if applicable)
3. Update the `rows` lazy initialization to call the new method
4. Consider adding categories/sections for different skill types

#### HTARowModel.h/.m
1. Add properties for:
   - `subtitle` (NSString) - Brief description of the skill
   - `category` (NSString) - Category grouping (e.g., "Household", "Finance", "Career")
   - `iconName` (NSString) - Asset catalog icon reference
   - `difficulty` (enum) - Beginner/Intermediate/Advanced
2. Update initializers and description methods accordingly

#### ViewController.m
1. Remove the unused `HTAItems` enum (lines 18-22) or update it to reflect actual content types
2. Update `heightForCollectionViewCellAtIndexPath:` to use model-based heights instead of hardcoded enum values
3. Implement `collectionView:didSelectItemAtIndexPath:` to handle topic selection

### Implementation Steps
1. Define 15-20 adult life skill topics with categories
2. Create model properties to support rich content
3. Implement content loading in HTADataManager
4. Update UI to display the new content properly
5. Remove prime number calculation logic

### Testing Criteria
- [ ] App launches without crashes
- [ ] Collection view displays at least 15 adult life skill topics
- [ ] Each topic has a meaningful title and category
- [ ] Cell heights are appropriately varied and visually balanced
- [ ] No prime numbers are displayed
- [ ] Memory usage is reasonable (no leaks)

### Acceptance Criteria
- HTADataManager creates at least 15 meaningful adult life skill topics
- All topics have titles, categories, and appropriate metadata
- UI correctly displays the new content structure
- Code is well-documented with comments explaining content organization
- No references to prime numbers remain in the codebase

### Documentation Updates
- Update README.md to describe the content structure
- Add inline code comments explaining content categories
- Document how to add new topics to the system

---

## TASK 2: Laundry Feature Implementation

### Feature Description
Implement the complete laundry educational feature. Currently, `HTALaundryViewController` is a minimal shell with no content.

### Problem Statement
The `HTALaundryViewController` class exists but contains no educational content, UI elements, or functionality. It's referenced by `HTALaundryRowModel` but serves no purpose.

### Affected Files
- `How To Adult/HTALaundryViewController.h`
- `How To Adult/HTALaundryViewController.m`
- `How To Adult/HTALaundryRowModel.h`
- `How To Adult/HTALaundryRowModel.m`

### Changes Needed

#### HTALaundryViewController.h
1. Add public properties:
   - `@property (nonatomic, readonly) HTALaundryRowModel *model;`

#### HTALaundryViewController.m
1. Add UI components:
   - `UIScrollView` for content
   - `UILabel` for title and sections
   - `UIImageView` for visual guides (optional)
   - `UITableView` or `UIStackView` for step-by-step instructions
2. Implement `viewDidLoad` with:
   - Title setup ("How to Do Laundry")
   - Content sections:
     - Sorting clothes (colors, fabrics, temperature)
     - Reading care labels
     - Detergent usage
     - Machine settings
     - Drying guidelines
     - Folding tips
3. Add proper layout constraints (Auto Layout)
4. Style the view controller appropriately
5. Implement `didReceiveMemoryWarning` with proper resource cleanup

#### HTALaundryRowModel.m
1. Add laundry-specific properties (if needed):
   - Steps array
   - Tips array
   - Common mistakes array
2. Populate data in initialization

### Implementation Steps
1. Design the laundry instruction content (research best practices)
2. Create the UI layout using UIScrollView and content containers
3. Implement section headers and step-by-step instructions
4. Add visual polish (colors, fonts, spacing)
5. Test on different device sizes
6. Add accessibility labels for VoiceOver support

### Testing Criteria
- [ ] Tapping "Laundry" cell navigates to HTALaundryViewController
- [ ] View controller displays comprehensive laundry instructions
- [ ] Content is readable and well-formatted
- [ ] Scrolling works smoothly on all device sizes
- [ ] Back navigation returns to main view
- [ ] No memory warnings during navigation
- [ ] Accessibility features work properly

### Acceptance Criteria
- HTALaundryViewController displays at least 5 instructional sections
- Content includes sorting, washing, drying, and folding guidance
- UI is polished and professional
- Navigation works seamlessly
- View controller properly retains and uses its model
- Code follows iOS best practices for view controller implementation

### Documentation Updates
- Add comments explaining the view structure
- Document the content organization
- Update README.md with screenshots (optional)

---

## TASK 3: Core Data Model Definition

### Feature Description
Define and implement the Core Data model schema to support data persistence for user progress, favorites, and custom notes.

### Problem Statement
The Core Data stack is configured in `AppDelegate.m`, and an `.xcdatamodeld` file exists, but the model contains no entities. This means Core Data is initialized but completely unused.

### Affected Files
- `How To Adult/How_To_Adult.xcdatamodeld/How_To_Adult.xcdatamodel/contents`
- `How To Adult/AppDelegate.h`
- `How To Adult/AppDelegate.m`
- `How To Adult/HTADataManager.m` (potentially)
- New files: Core Data entity class files (generated or manual)

### Changes Needed

#### Core Data Model (How_To_Adult.xcdatamodel)
1. Define entities:
   - **Topic** entity:
     - `identifier` (String, indexed)
     - `title` (String)
     - `category` (String)
     - `isCompleted` (Boolean, default NO)
     - `isFavorite` (Boolean, default NO)
     - `lastViewedDate` (Date, optional)
     - `notes` (String, optional)
     - Relationship to `Progress` (one-to-one, optional)

   - **Progress** entity (optional, for tracking completion):
     - `completionPercentage` (Float, default 0.0)
     - `stepsCompleted` (Integer 32, default 0)
     - `totalSteps` (Integer 32)
     - Relationship to `Topic` (one-to-one)

2. Configure entity properties:
   - Set proper data types
   - Define default values
   - Set up indexes for frequently queried fields
   - Configure delete rules for relationships

#### AppDelegate.m
1. Keep existing Core Data stack (already implemented)
2. Add error logging that doesn't use `abort()` (see Task 4)
3. Consider adding migration support for future schema changes

#### HTADataManager.m
1. Add Core Data integration:
   - Import Core Data framework
   - Add method to sync in-memory rows with Core Data
   - Implement `loadPersistedTopics` to restore user data
   - Implement `saveTopicProgress:` to persist changes
   - Add methods to mark topics as favorite/completed

2. Create new methods:
```objective-c
- (void)saveTopicData;
- (void)loadPersistedData;
- (void)markTopicCompleted:(NSString *)identifier;
- (void)toggleTopicFavorite:(NSString *)identifier;
- (void)addNotesToTopic:(NSString *)identifier notes:(NSString *)notes;
```

#### New Generated Files
- Generate `Topic+CoreDataClass.h/.m`
- Generate `Topic+CoreDataProperties.h/.m`
- Generate `Progress+CoreDataClass.h/.m` (if using Progress entity)
- Generate `Progress+CoreDataProperties.h/.m` (if using Progress entity)

### Implementation Steps
1. Open `.xcdatamodeld` in Xcode
2. Define entities with attributes and relationships
3. Generate NSManagedObject subclasses (Editor → Create NSManagedObject Subclass)
4. Update HTADataManager to integrate Core Data
5. Implement persistence methods
6. Add migration support configuration
7. Test data persistence across app launches

### Testing Criteria
- [ ] Core Data model compiles without errors
- [ ] Entity classes are generated correctly
- [ ] App can create and save Topic entities
- [ ] Data persists across app restarts
- [ ] Favorites and completion status are preserved
- [ ] Notes are saved and loaded correctly
- [ ] No Core Data errors in console
- [ ] Migration works if schema changes (future-proofing)

### Acceptance Criteria
- Core Data model defines at least Topic entity with all required attributes
- Generated entity classes integrate cleanly with existing code
- HTADataManager successfully persists and loads data
- User progress (favorites, completion, notes) survives app termination
- Core Data stack handles errors gracefully (no crashes)
- Code includes proper Core Data best practices (background contexts for heavy operations)

### Documentation Updates
- Document the Core Data schema in README.md
- Add inline comments explaining entity relationships
- Create a data flow diagram showing Core Data integration
- Document how to perform schema migrations

---

## TASK 4: Production-Ready Error Handling

### Feature Description
Replace the development-only `abort()` calls in Core Data error handling with production-appropriate error logging and recovery.

### Problem Statement
`AppDelegate.m` uses `abort()` in two places (lines 76 and 94) when Core Data errors occur. This is explicitly noted as not suitable for shipping applications and will cause crashes in production.

### Affected Files
- `How To Adult/AppDelegate.m`

### Changes Needed

#### AppDelegate.m - persistentContainer error handler (line 62-78)
Replace:
```objective-c
NSLog(@"Unresolved error %@, %@", error, error.userInfo);
abort();
```

With:
```objective-c
NSLog(@"Core Data store failed to load: %@, %@", error, error.userInfo);

// Attempt recovery based on error type
NSDictionary *userInfo = error.userInfo;
if ([error.domain isEqualToString:NSCocoaErrorDomain]) {
    // Handle specific Core Data errors
    switch (error.code) {
        case NSPersistentStoreIncompatibleVersionHashError:
        case NSMigrationMissingSourceModelError:
            // Model migration failed - reset the store
            [self resetPersistentStore];
            break;

        default:
            // Log error and notify user
            [self handleCriticalDataError:error];
            break;
    }
}
```

#### AppDelegate.m - saveContext error handler (line 90-95)
Replace:
```objective-c
NSLog(@"Unresolved error %@, %@", error, error.userInfo);
abort();
```

With:
```objective-c
NSLog(@"Core Data save failed: %@, %@", error, error.userInfo);

// Attempt to rollback and notify user
[context rollback];
[self handleDataSaveError:error];
```

#### AppDelegate.m - Add new error handling methods
```objective-c
- (void)resetPersistentStore {
    NSLog(@"Resetting persistent store due to migration failure");

    NSURL *storeURL = [[self applicationDocumentsDirectory]
                       URLByAppendingPathComponent:@"How_To_Adult.sqlite"];
    NSError *error = nil;

    // Remove old store
    [[NSFileManager defaultManager] removeItemAtURL:storeURL error:&error];

    // Reinitialize
    _persistentContainer = nil;
    [self persistentContainer]; // Trigger recreation
}

- (void)handleCriticalDataError:(NSError *)error {
    // In production, you might:
    // 1. Log to crash reporting service (Crashlytics, Sentry, etc.)
    // 2. Show alert to user
    // 3. Provide fallback to in-memory store

    NSLog(@"Critical Core Data error: %@", error);

    // Show user-friendly alert
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController
            alertControllerWithTitle:@"Data Error"
            message:@"There was a problem loading your data. The app will continue with default settings."
            preferredStyle:UIAlertControllerStyleAlert];

        [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                                 style:UIAlertActionStyleDefault
                                               handler:nil]];

        UIViewController *rootVC = self.window.rootViewController;
        [rootVC presentViewController:alert animated:YES completion:nil];
    });
}

- (void)handleDataSaveError:(NSError *)error {
    NSLog(@"Data save error: %@", error);

    // Notify user that changes weren't saved
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController
            alertControllerWithTitle:@"Save Failed"
            message:@"Your recent changes could not be saved. Please try again."
            preferredStyle:UIAlertControllerStyleAlert];

        [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                                 style:UIAlertActionStyleDefault
                                               handler:nil]];

        UIViewController *rootVC = self.window.rootViewController;
        [rootVC presentViewController:alert animated:YES completion:nil];
    });
}

- (NSURL *)applicationDocumentsDirectory {
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory
                                                   inDomains:NSUserDomainMask] lastObject];
}
```

### Implementation Steps
1. Replace both `abort()` calls with proper error handling
2. Implement `resetPersistentStore` method
3. Implement `handleCriticalDataError:` method
4. Implement `handleDataSaveError:` method
5. Add `applicationDocumentsDirectory` helper method
6. Test error scenarios (simulate by corrupting database)
7. Verify user alerts display correctly

### Testing Criteria
- [ ] App handles store loading errors without crashing
- [ ] App handles save errors without crashing
- [ ] User receives appropriate error messages
- [ ] Context rollback works correctly on save failures
- [ ] Store reset recovers from migration errors
- [ ] No `abort()` calls remain in production code
- [ ] Error logs are clear and actionable
- [ ] App continues functioning after non-critical errors

### Acceptance Criteria
- All `abort()` calls are removed from AppDelegate.m
- Core Data errors are logged with NSLog (or analytics service)
- Users receive user-friendly error messages via UIAlertController
- Failed saves trigger context rollback
- Migration errors trigger store reset with user notification
- App remains stable and functional after error recovery
- Error handling follows iOS best practices

### Documentation Updates
- Add comments explaining error handling strategy
- Document error recovery procedures in README.md
- Note future improvement opportunities (crash reporting integration)

---

## TASK 5: Dynamic Cell Height Management

### Feature Description
Refactor the cell height calculation system to be data-driven rather than hardcoded, allowing the model to control cell heights.

### Problem Statement
`ViewController.m` contains a hardcoded `HTAItems` enum (lines 18-22) and switch statement (lines 120-134) that assigns heights based on index position. This is fragile and doesn't scale as content is added/removed. The enum references "Laundry" and "Compliments" topics that may not exist in the data.

### Affected Files
- `How To Adult/ViewController.m`
- `How To Adult/HTARowModel.h`
- `How To Adult/HTARowModel.m`

### Changes Needed

#### HTARowModel.h
Add property:
```objective-c
@property (nonatomic) CGFloat preferredHeight;
```

#### HTARowModel.m
1. Update `init` method to set a random or category-based `preferredHeight`:
```objective-c
// Random height between min and max
self.preferredHeight = arc4random_uniform(150) + 50; // 50-200 points

// OR category-based heights:
// self.preferredHeight = [self heightForCategory:self.category];
```

2. Optionally add method:
```objective-c
- (CGFloat)heightForCategory:(NSString *)category {
    if ([category isEqualToString:@"Featured"]) return 150.0f;
    if ([category isEqualToString:@"Quick Tips"]) return 80.0f;
    if ([category isEqualToString:@"In-Depth"]) return 200.0f;
    return 120.0f; // default
}
```

3. Ensure `preferredHeight` respects `minHeight` and `maxHeight` constraints:
```objective-c
- (CGFloat)preferredHeight {
    CGFloat height = _preferredHeight;
    height = MAX(height, self.minHeight);
    height = MIN(height, self.maxHeight);
    return height;
}
```

#### ViewController.m
1. **Remove** the `HTAItems` enum (lines 18-22):
```objective-c
// DELETE THIS:
typedef NS_ENUM(NSUInteger, HTAItems) {
    HTAItemsLaundry,
    HTAItemsCompliments,
    HTAItemsCount,
};
```

2. **Replace** `heightForCollectionViewCellAtIndexPath:` implementation (lines 117-135):

Replace:
```objective-c
- (CGFloat)heightForCollectionViewCellAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat height = 0.0f;

    switch (indexPath.row) {
        case HTAItemsLaundry:
            height = 100.0f;
            break;

        case HTAItemsCompliments:
            height = 50.0f;
            break;

        default:
            height = arc4random()%3 * 50 + 50;
            break;
    }

    return height;
}
```

With:
```objective-c
- (CGFloat)heightForCollectionViewCellAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row >= HTADataManager.rows.count) {
        return 100.0f; // Fallback height
    }

    HTARowModel *model = HTADataManager.rows[indexPath.row];
    return model.preferredHeight;
}
```

### Implementation Steps
1. Add `preferredHeight` property to HTARowModel.h
2. Implement height calculation logic in HTARowModel.m
3. Remove HTAItems enum from ViewController.m
4. Simplify `heightForCollectionViewCellAtIndexPath:` to use model property
5. Test various height values to ensure layout works correctly
6. Verify min/max height constraints are respected

### Testing Criteria
- [ ] Collection view displays with varied cell heights
- [ ] Cell heights are determined by model data, not index
- [ ] Layout remains stable when items are added/removed
- [ ] No hardcoded height values based on position
- [ ] Height constraints (min/max) are enforced
- [ ] UI looks balanced and professional
- [ ] No crashes when accessing model heights

### Acceptance Criteria
- HTARowModel controls its own preferred height
- ViewController's height calculation is data-driven (one-liner)
- HTAItems enum is completely removed
- All hardcoded height switches/conditionals based on index are eliminated
- Code is more maintainable and scalable
- Layout adapts correctly to dynamic content

### Documentation Updates
- Add comments explaining height calculation strategy
- Document how to set custom heights for specific topics
- Update README.md with layout architecture explanation

---

## TASK 6: Unit Test Implementation

### Feature Description
Implement comprehensive unit tests for the core business logic, models, and data management classes.

### Problem Statement
`How_To_AdultTests.m` contains only placeholder test methods (`testExample` and `testPerformanceExample`) with no actual test logic. The test target exists but provides no code coverage.

### Affected Files
- `How To AdultTests/How_To_AdultTests.m`
- Potentially new test files for specific components

### Changes Needed

#### How_To_AdultTests.m
1. **Import necessary headers**:
```objective-c
#import "HTADataManager.h"
#import "HTARowModel.h"
#import "HTALaundryRowModel.h"
#import "HTACollectionViewLayout.h"
```

2. **Implement HTADataManager tests**:
```objective-c
- (void)testDataManagerSingleton {
    HTADataManager *manager1 = [HTADataManager sharedManager];
    HTADataManager *manager2 = [HTADataManager sharedManager];
    XCTAssertEqual(manager1, manager2, @"Singleton should return same instance");
}

- (void)testDataManagerRowsNotEmpty {
    NSArray *rows = [HTADataManager rows];
    XCTAssertNotNil(rows, @"Rows should not be nil");
    XCTAssertGreaterThan(rows.count, 0, @"Rows should contain data");
}

- (void)testRowsContainValidData {
    NSArray *rows = [HTADataManager rows];
    for (HTARowModel *row in rows) {
        XCTAssertNotNil(row.title, @"Each row should have a title");
        XCTAssertNotNil(row.backgroundColor, @"Each row should have a background color");
        XCTAssertNotNil(row.textColor, @"Each row should have a text color");
    }
}
```

3. **Implement HTARowModel tests**:
```objective-c
- (void)testRowModelInitialization {
    HTARowModel *model = [[HTARowModel alloc] init];
    XCTAssertNotNil(model, @"Model should initialize");
    XCTAssertNotNil(model.backgroundColor, @"Model should have a background color");
    XCTAssertNotNil(model.textColor, @"Model should have a text color");
}

- (void)testRowModelColorContrast {
    HTARowModel *model = [[HTARowModel alloc] init];

    // Background should be darker (saturation high, brightness low)
    CGFloat bgSaturation, bgBrightness;
    [model.backgroundColor getHue:NULL saturation:&bgSaturation brightness:&bgBrightness alpha:NULL];

    // Text should be lighter
    CGFloat textSaturation, textBrightness;
    [model.textColor getHue:NULL saturation:&textSaturation brightness:&textBrightness alpha:NULL];

    XCTAssertLessThan(bgBrightness, textBrightness, @"Text should be lighter than background");
}

- (void)testRowModelHeightConstraints {
    HTARowModel *model = [[HTARowModel alloc] init];
    model.minHeight = 50.0f;
    model.maxHeight = 200.0f;
    model.proportionalHeight = 0.5f;

    CGFloat height = [model defaultHeight];
    XCTAssertGreaterThanOrEqual(height, model.minHeight, @"Height should respect minimum");
    XCTAssertLessThanOrEqual(height, model.maxHeight, @"Height should respect maximum");
}

- (void)testRowModelDescription {
    HTARowModel *model = [[HTARowModel alloc] init];
    model.title = @"Test Title";
    NSString *description = [model description];
    XCTAssertTrue([description containsString:@"Test Title"], @"Description should include title");
}
```

4. **Implement HTALaundryRowModel tests**:
```objective-c
- (void)testLaundryRowModelInitialization {
    HTALaundryRowModel *model = [[HTALaundryRowModel alloc] init];
    XCTAssertNotNil(model, @"Laundry model should initialize");
    XCTAssertNotNil(model.representativeViewController, @"Should create view controller");
}

- (void)testLaundryViewControllerType {
    HTALaundryRowModel *model = [[HTALaundryRowModel alloc] init];
    XCTAssertTrue([model.representativeViewController isKindOfClass:[HTALaundryViewController class]],
                  @"Should create correct view controller type");
}
```

5. **Replace placeholder tests**:
```objective-c
- (void)testExample {
    // Remove placeholder comment
    [self testDataManagerSingleton];
    [self testDataManagerRowsNotEmpty];
}
```

6. **Add performance tests**:
```objective-c
- (void)testRowCreationPerformance {
    [self measureBlock:^{
        for (int i = 0; i < 100; i++) {
            HTARowModel *model = [[HTARowModel alloc] init];
            model.title = [NSString stringWithFormat:@"Item %d", i];
        }
    }];
}

- (void)testDataManagerPerformance {
    [self measureBlock:^{
        NSArray *rows = [HTADataManager rows];
        for (HTARowModel *row in rows) {
            CGFloat height = [row defaultHeight];
        }
    }];
}
```

#### Consider creating separate test files:
- `HTADataManagerTests.m` - Dedicated data manager tests
- `HTARowModelTests.m` - Dedicated model tests
- `HTACollectionViewLayoutTests.m` - Layout calculation tests

### Implementation Steps
1. Remove placeholder comments and empty implementations
2. Add test cases for HTADataManager singleton pattern
3. Add test cases for HTARowModel initialization and properties
4. Add test cases for color generation and contrast
5. Add test cases for height calculations and constraints
6. Add test cases for HTALaundryRowModel
7. Add performance benchmarks
8. Run all tests and ensure they pass
9. Achieve at least 70% code coverage for model layer

### Testing Criteria
- [ ] All unit tests pass without failures
- [ ] Tests cover HTADataManager singleton behavior
- [ ] Tests verify row data integrity
- [ ] Tests validate color generation and contrast
- [ ] Tests check height calculation constraints
- [ ] Tests verify HTALaundryRowModel initialization
- [ ] Performance tests complete within reasonable time
- [ ] Code coverage is at least 70% for tested classes
- [ ] Tests are reliable (no flaky tests)

### Acceptance Criteria
- At least 15 meaningful unit test methods implemented
- All placeholder test methods are removed or properly implemented
- Tests cover critical business logic (data loading, model initialization, calculations)
- All tests pass successfully
- Performance tests establish baseline metrics
- Test code follows XCTest best practices
- Tests are maintainable and well-documented

### Documentation Updates
- Add comments explaining what each test validates
- Document test organization and naming conventions
- Update README.md with instructions for running tests
- Include code coverage goals and current metrics

---

## TASK 7: UI Test Implementation

### Feature Description
Implement automated UI tests to validate user interactions, navigation, and interface elements.

### Problem Statement
`How_To_AdultUITests.m` contains only a placeholder `testExample` method with no actual UI test automation. The UI testing infrastructure exists but is unused.

### Affected Files
- `How To AdultUITests/How_To_AdultUITests.m`
- Potentially new UI test files for specific flows

### Changes Needed

#### How_To_AdultUITests.m

1. **Update setUp method** to configure test environment:
```objective-c
- (void)setUp {
    [super setUp];

    self.continueAfterFailure = NO;

    XCUIApplication *app = [[XCUIApplication alloc] init];
    [app launch];

    // Add UI interruption handler for alerts (if needed)
    [self addUIInterruptionMonitorWithDescription:@"System Dialog" handler:^BOOL(XCUIElement * _Nonnull interruptingElement) {
        XCUIElement *button = interruptingElement.buttons[@"Allow"];
        if (button.exists) {
            [button tap];
            return YES;
        }
        return NO;
    }];
}
```

2. **Implement collection view tests**:
```objective-c
- (void)testCollectionViewExists {
    XCUIApplication *app = [[XCUIApplication alloc] init];
    XCUIElement *collectionView = app.collectionViews.firstMatch;

    XCTAssertTrue(collectionView.exists, @"Collection view should exist");
}

- (void)testCollectionViewContainsCells {
    XCUIApplication *app = [[XCUIApplication alloc] init];

    NSUInteger cellCount = app.collectionViews.cells.count;
    XCTAssertGreaterThan(cellCount, 0, @"Collection view should contain cells");
}

- (void)testCellsHaveTitles {
    XCUIApplication *app = [[XCUIApplication alloc] init];

    XCUIElementQuery *cells = app.collectionViews.cells;
    XCUIElement *firstCell = [cells elementBoundByIndex:0];

    XCTAssertTrue(firstCell.exists, @"First cell should exist");

    // Check that cell contains text
    XCUIElement *label = firstCell.staticTexts.firstMatch;
    XCTAssertTrue(label.exists, @"Cell should contain a label");
}
```

3. **Implement navigation tests**:
```objective-c
- (void)testTappingCellNavigates {
    XCUIApplication *app = [[XCUIApplication alloc] init];

    // Get initial cell count
    XCUIElementQuery *cells = app.collectionViews.cells;
    if (cells.count == 0) {
        XCTFail(@"No cells available to tap");
        return;
    }

    XCUIElement *firstCell = [cells elementBoundByIndex:0];
    [firstCell tap];

    // Wait for potential navigation
    // Note: This test needs to be updated once navigation is implemented
    // For now, verify the tap doesn't crash the app
    XCTAssertTrue(app.exists, @"App should still be running after cell tap");
}

- (void)testBackNavigation {
    XCUIApplication *app = [[XCUIApplication alloc] init];

    XCUIElementQuery *cells = app.collectionViews.cells;
    if (cells.count == 0) {
        XCTFail(@"No cells available");
        return;
    }

    // Tap a cell to navigate
    XCUIElement *cell = [cells elementBoundByIndex:0];
    [cell tap];

    // Look for back button
    XCUIElement *backButton = app.navigationBars.buttons.firstMatch;
    if (backButton.exists) {
        [backButton tap];

        // Verify we're back to collection view
        XCTAssertTrue(app.collectionViews.firstMatch.exists, @"Should return to collection view");
    }
}
```

4. **Implement scroll tests**:
```objective-c
- (void)testScrollingCollectionView {
    XCUIApplication *app = [[XCUIApplication alloc] init];
    XCUIElement *collectionView = app.collectionViews.firstMatch;

    XCTAssertTrue(collectionView.exists, @"Collection view should exist");

    // Swipe up to scroll
    [collectionView swipeUp];

    // Verify app is still responsive
    XCTAssertTrue(collectionView.exists, @"Collection view should still exist after scrolling");

    // Swipe down
    [collectionView swipeDown];
}
```

5. **Implement accessibility tests**:
```objective-c
- (void)testAccessibilityElements {
    XCUIApplication *app = [[XCUIApplication alloc] init];

    XCUIElementQuery *cells = app.collectionViews.cells;
    if (cells.count > 0) {
        XCUIElement *firstCell = [cells elementBoundByIndex:0];

        // Verify cell is accessible
        XCTAssertTrue(firstCell.isAccessibilityElement ||
                      firstCell.descendants[XCUIElementTypeAny].count > 0,
                      @"Cells should be accessible");
    }
}
```

6. **Implement appearance tests**:
```objective-c
- (void)testLaunchPerformance {
    if (@available(iOS 13.0, *)) {
        [self measureWithMetrics:@[[[XCTApplicationLaunchMetric alloc] init]] block:^{
            [[[XCUIApplication alloc] init] launch];
        }];
    }
}

- (void)testAppearanceOnLaunch {
    XCUIApplication *app = [[XCUIApplication alloc] init];

    // Take screenshot for visual comparison
    XCTAttachment *screenshot = [XCTAttachment attachmentWithScreenshot:[[XCUIScreen mainScreen] screenshot]];
    screenshot.name = @"Launch Screen";
    screenshot.lifetime = XCTAttachmentLifetimeKeepAlways;
    [self addAttachment:screenshot];

    XCTAssertTrue(app.collectionViews.firstMatch.exists, @"Main view should appear on launch");
}
```

7. **Replace placeholder test**:
```objective-c
- (void)testExample {
    // Remove placeholder comment
    [self testCollectionViewExists];
    [self testCollectionViewContainsCells];
}
```

### Implementation Steps
1. Update setUp method with proper app launch
2. Implement basic UI existence tests
3. Implement cell interaction tests
4. Implement navigation flow tests
5. Implement scrolling tests
6. Implement accessibility tests
7. Implement performance tests
8. Run all UI tests on simulator and device
9. Add screenshots for documentation

### Testing Criteria
- [ ] All UI tests pass on iPhone simulator
- [ ] All UI tests pass on iPad simulator
- [ ] Tests verify collection view displays correctly
- [ ] Tests verify cells are interactive
- [ ] Tests verify navigation works (when implemented)
- [ ] Tests verify scrolling functionality
- [ ] Tests verify accessibility compliance
- [ ] Launch performance test completes successfully
- [ ] No test flakiness (tests pass consistently)

### Acceptance Criteria
- At least 10 meaningful UI test methods implemented
- All placeholder test methods are removed or properly implemented
- Tests cover main user flows (viewing list, navigation, scrolling)
- All tests pass on both iPhone and iPad simulators
- Tests include performance benchmarks
- Tests generate screenshots for documentation
- UI tests follow XCTest best practices
- Tests are maintainable and reliable

### Documentation Updates
- Add comments explaining what each UI test validates
- Document UI test organization and naming conventions
- Update README.md with UI testing instructions
- Include screenshots from test runs
- Document how to run UI tests in different configurations

---

## TASK 8: Project Documentation

### Feature Description
Create comprehensive project documentation including README.md, code architecture overview, and setup/contribution guidelines.

### Problem Statement
The project has no README.md file or other documentation. New developers (or future maintainers) have no guide for understanding the project structure, setting it up, or contributing.

### Affected Files
- **New file**: `README.md` (root directory)
- **New file**: `ARCHITECTURE.md` (optional, detailed architecture)
- **New file**: `CONTRIBUTING.md` (optional, contribution guidelines)
- Updates to existing code comments

### Changes Needed

#### README.md (create new file)
```markdown
# How To Adult

An iOS application that teaches essential life skills for adults. Learn practical knowledge about laundry, cooking, budgeting, job interviews, and more through an intuitive, colorful interface.

## 📱 Overview

How To Adult presents life skills education through a dynamic, Pinterest-style grid interface. Each topic is displayed as a colorful card that users can tap to learn step-by-step instructions for common adult tasks.

## ✨ Features

- **Diverse Topics**: 15+ life skill categories including household tasks, financial literacy, and career skills
- **Interactive UI**: Beautiful waterfall layout with varied cell heights
- **Progress Tracking**: Mark topics as completed and add personal notes (via Core Data)
- **Favorites**: Save your most-used topics for quick access
- **Accessibility**: Full VoiceOver support for visually impaired users

## 🏗️ Architecture

### Technology Stack
- **Language**: Objective-C
- **Minimum iOS Version**: iOS 8.0+
- **Frameworks**: UIKit, Core Data
- **Design Pattern**: Model-View-Controller (MVC)

### Key Components

#### Models
- **HTARowModel**: Base model for topic data (title, colors, height)
- **HTALaundryRowModel**: Specialized model for laundry feature
- **HTADataManager**: Singleton managing all topic data

#### Views
- **HTACollectionViewCell**: Custom cell displaying topic title with colored background
- **HTACollectionViewLayout**: Custom waterfall/masonry layout

#### Controllers
- **ViewController**: Main controller managing the topic grid
- **HTALaundryViewController**: Detail view for laundry instructions
- **AppDelegate**: App lifecycle and Core Data stack management

## 🚀 Getting Started

### Prerequisites
- Xcode 8.0 or later
- iOS 8.0+ SDK
- Mac running macOS 10.11+

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/fennelouski/How-To-Adult.git
   cd How-To-Adult
   ```

2. **Open in Xcode**
   ```bash
   open "How To Adult.xcodeproj"
   ```

3. **Build and Run**
   - Select a simulator or connected device
   - Press `Cmd+R` or click the Run button
   - The app will launch showing the topic grid

### Running Tests

#### Unit Tests
```bash
# In Xcode
Cmd+U

# Or via command line
xcodebuild test -project "How To Adult.xcodeproj" -scheme "How To Adult" -destination 'platform=iOS Simulator,name=iPhone 14'
```

#### UI Tests
```bash
# In Xcode
Cmd+U (runs all tests including UI)

# Or run UI tests specifically
xcodebuild test -project "How To Adult.xcodeproj" -scheme "How To Adult" -destination 'platform=iOS Simulator,name=iPhone 14' -only-testing:How_To_AdultUITests
```

## 📚 Project Structure

```
How-To-Adult/
├── How To Adult/              # Main application code
│   ├── Models/
│   │   ├── HTARowModel.h/m
│   │   ├── HTALaundryRowModel.h/m
│   │   └── HTADataManager.h/m
│   ├── Views/
│   │   ├── HTACollectionViewCell.h/m
│   │   └── HTACollectionViewLayout.h/m
│   ├── Controllers/
│   │   ├── ViewController.h/m
│   │   ├── HTALaundryViewController.h/m
│   │   └── AppDelegate.h/m
│   ├── Resources/
│   │   ├── Assets.xcassets/
│   │   ├── Base.lproj/
│   │   └── Info.plist
│   └── CoreData/
│       └── How_To_Adult.xcdatamodeld/
├── How To AdultTests/         # Unit tests
├── How To AdultUITests/       # UI automation tests
└── README.md                  # This file
```

## 🎨 Color System

The app uses an HSB (Hue, Saturation, Brightness) color system:
- **Background**: Random hue, 100% saturation, 30% brightness (dark, vibrant)
- **Text**: Matching hue, 30% saturation, 100% brightness (light, readable)

This ensures high contrast and readability while maintaining visual cohesion.

## 💾 Data Persistence

Core Data is used to persist:
- **Completion Status**: Track which topics you've mastered
- **Favorites**: Quick access to frequently used topics
- **Notes**: Add personal tips and reminders to any topic

## 🧪 Testing

### Code Coverage
Current coverage: ~70% (goal: 80%+)

### Test Categories
- **Unit Tests**: Model logic, data management, calculations
- **UI Tests**: Navigation, interactions, accessibility
- **Performance Tests**: Launch time, scroll performance, data loading

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Write or update tests as needed
5. Ensure all tests pass
6. Commit your changes (`git commit -m 'Add amazing feature'`)
7. Push to the branch (`git push origin feature/amazing-feature`)
8. Open a Pull Request

### Code Style
- Follow existing Objective-C conventions
- Use meaningful variable and method names
- Add comments for complex logic
- Keep methods focused and concise

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👤 Author

**Nathan Fennel**

## 🙏 Acknowledgments

- Inspired by the need for practical life skills education
- Built with love for anyone navigating adulthood

## 📞 Support

For issues, questions, or suggestions:
- Open an issue on GitHub
- Contact: [your-email@example.com]

---

**Happy Adulting! 🎉**
```

#### Code Comment Updates
Add comprehensive header comments to each major file:

**HTADataManager.h**:
```objective-c
/**
 * HTADataManager
 *
 * Singleton class responsible for managing all topic data in the application.
 * Provides centralized access to HTARowModel instances and handles data
 * initialization, Core Data synchronization, and topic management.
 *
 * Usage:
 *   NSArray *topics = [HTADataManager rows];
 */
```

**HTACollectionViewLayout.h**:
```objective-c
/**
 * HTACollectionViewLayout
 *
 * Custom UICollectionViewLayout implementing a waterfall/masonry style layout.
 * Cells are arranged in columns with variable heights, creating a Pinterest-like
 * appearance. The layout automatically balances columns for optimal space usage.
 *
 * Delegate Protocol:
 *   Implement HTACollectionViewLayoutDelegate to provide:
 *   - Number of columns
 *   - Individual cell heights
 */
```

### Implementation Steps
1. Create README.md with comprehensive project overview
2. Add installation and setup instructions
3. Document architecture and key components
4. Add testing instructions and coverage goals
5. Include contribution guidelines
6. Add code comments to all public classes and methods
7. Create ARCHITECTURE.md for detailed technical documentation (optional)
8. Add inline comments to complex algorithms
9. Generate documentation with HeaderDoc or Doxygen (optional)

### Testing Criteria
- [ ] README.md renders correctly on GitHub
- [ ] All links in documentation work
- [ ] Code examples in README are accurate
- [ ] Installation instructions can be followed successfully
- [ ] Testing instructions work as documented
- [ ] Project structure diagram matches actual structure
- [ ] Architecture descriptions are accurate
- [ ] Documentation is clear and comprehensive

### Acceptance Criteria
- README.md exists and is at least 200 lines
- Documentation covers: overview, features, architecture, setup, testing, and contributing
- All major classes have header documentation comments
- Complex algorithms have inline explanatory comments
- Installation instructions are tested and verified
- Code examples are accurate and functional
- Documentation is professional and well-formatted
- Links and references are valid

### Documentation Updates
- This task IS the documentation update
- Ensure README is kept up-to-date with future changes
- Add CHANGELOG.md to track version changes (optional)

---

## TASK 9: LICENSE File Completion

### Feature Description
Complete the MIT LICENSE file by adding the copyright holder's name and year.

### Problem Statement
The LICENSE file contains the MIT License text but has an incomplete copyright line (line 3) that reads "Copyright (c) 2017" without the copyright holder's name.

### Affected Files
- `LICENSE`

### Changes Needed

#### LICENSE (line 3)
Replace:
```
Copyright (c) 2017
```

With:
```
Copyright (c) 2017 Nathan Fennel
```

### Implementation Steps
1. Open LICENSE file
2. Update line 3 with copyright holder name
3. Verify the year (2017) is correct
4. Verify MIT License text is complete and accurate
5. Save the file

### Testing Criteria
- [ ] LICENSE file contains copyright holder name
- [ ] Year is correct (2017)
- [ ] MIT License text is complete
- [ ] File is properly formatted

### Acceptance Criteria
- COPYRIGHT line is complete: "Copyright (c) 2017 Nathan Fennel"
- MIT License text is intact and properly formatted
- File follows standard MIT License format
- No trailing whitespace or formatting issues

### Documentation Updates
- Reference the LICENSE file in README.md (already included in Task 8)
- Add license badge to README.md (optional)

---

## TASK 10: Cell Selection Handling

### Feature Description
Implement proper cell selection handling to enable navigation from the main collection view to detail view controllers for each topic.

### Problem Statement
`ViewController.m` does not implement `collectionView:didSelectItemAtIndexPath:`, so tapping cells has no effect. The architecture suggests navigation to detail views (as evidenced by HTALaundryViewController), but this is not wired up.

### Affected Files
- `How To Adult/ViewController.m`
- `How To Adult/HTARowModel.h`
- `How To Adult/HTARowModel.m`
- All topic-specific view controllers (HTALaundryViewController, etc.)

### Changes Needed

#### HTARowModel.h
Add property:
```objective-c
@property (nonatomic, strong) UIViewController *representativeViewController;
```

#### HTARowModel.m
Update to instantiate a default detail view controller (or nil):
```objective-c
- (instancetype)init {
    self = [super init];
    if (self) {
        // ... existing initialization ...

        // By default, topics don't have a detail view
        // Subclasses (like HTALaundryRowModel) can override
        self.representativeViewController = nil;
    }
    return self;
}
```

#### ViewController.m
Add delegate method:
```objective-c
#pragma mark - Collection View Delegate

- (void)collectionView:(UICollectionView *)collectionView
didSelectItemAtIndexPath:(NSIndexPath *)indexPath {

    if (![collectionView isEqual:self.collectionView]) {
        return;
    }

    if (indexPath.row >= HTADataManager.rows.count) {
        return;
    }

    HTARowModel *model = HTADataManager.rows[indexPath.row];

    if (model.representativeViewController) {
        // Navigate to the detail view controller
        [self.navigationController pushViewController:model.representativeViewController
                                              animated:YES];
    } else {
        // Show a generic detail view or alert
        [self showGenericDetailForModel:model];
    }

    // Deselect the cell with animation
    [collectionView deselectItemAtIndexPath:indexPath animated:YES];
}

- (void)showGenericDetailForModel:(HTARowModel *)model {
    // Create a simple detail view controller for topics without custom VCs
    UIViewController *detailVC = [[UIViewController alloc] init];
    detailVC.view.backgroundColor = [UIColor whiteColor];
    detailVC.title = model.title;

    // Add a label explaining this is a placeholder
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.text = [NSString stringWithFormat:@"Detail view for '%@' coming soon!", model.title];
    label.textAlignment = NSTextAlignmentCenter;
    label.numberOfLines = 0;
    [detailVC.view addSubview:label];

    // Center the label
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [label.centerXAnchor constraintEqualToAnchor:detailVC.view.centerXAnchor],
        [label.centerYAnchor constraintEqualToAnchor:detailVC.view.centerYAnchor],
        [label.leadingAnchor constraintEqualToAnchor:detailVC.view.leadingAnchor constant:20],
        [label.trailingAnchor constraintEqualToAnchor:detailVC.view.trailingAnchor constant:-20]
    ]];

    [self.navigationController pushViewController:detailVC animated:YES];
}
```

#### Update Main Storyboard or AppDelegate
Ensure the root ViewController is embedded in a UINavigationController:

**Option A: In Main.storyboard** (via Xcode Interface Builder)
1. Select the ViewController in the storyboard
2. Editor → Embed In → Navigation Controller

**Option B: In AppDelegate.m** (programmatically):
```objective-c
- (BOOL)application:(UIApplication *)application
didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    // Get the root view controller from storyboard
    ViewController *rootVC = (ViewController *)self.window.rootViewController;

    // Embed in navigation controller
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:rootVC];
    self.window.rootViewController = navController;
    [self.window makeKeyAndVisible];

    return YES;
}
```

### Implementation Steps
1. Add `representativeViewController` property to HTARowModel.h
2. Implement `collectionView:didSelectItemAtIndexPath:` in ViewController.m
3. Implement `showGenericDetailForModel:` helper method
4. Embed ViewController in UINavigationController (storyboard or code)
5. Verify HTALaundryRowModel already sets `representativeViewController` (it does!)
6. Test navigation by tapping cells
7. Test back navigation
8. Add visual polish (navigation bar styling, transitions)

### Testing Criteria
- [ ] Tapping any cell triggers selection handler
- [ ] Cells with representativeViewController navigate to detail views
- [ ] HTALaundryRowModel navigates to HTALaundryViewController
- [ ] Cells without custom VCs show generic detail view
- [ ] Back button appears and functions correctly
- [ ] Cell deselection animation works
- [ ] Navigation is smooth and performant
- [ ] No crashes when tapping cells rapidly

### Acceptance Criteria
- `collectionView:didSelectItemAtIndexPath:` is implemented
- ViewController is embedded in UINavigationController
- Tapping laundry cell navigates to HTALaundryViewController
- Other cells navigate to generic placeholder detail view
- Navigation bar shows topic title in detail view
- Back button returns to collection view
- Selection state is properly managed
- Code follows iOS navigation best practices

### Documentation Updates
- Add comments explaining navigation architecture
- Document how to create new detail view controllers
- Update README.md with navigation flow diagram
- Add inline comments for selection handling logic

---

## Summary Statistics

### Total Tasks: 10
1. Core Content Implementation
2. Laundry Feature Implementation
3. Core Data Model Definition
4. Production-Ready Error Handling
5. Dynamic Cell Height Management
6. Unit Test Implementation
7. UI Test Implementation
8. Project Documentation
9. LICENSE File Completion
10. Cell Selection Handling

### Priority Levels (Suggested Order)

**High Priority (Blockers for functionality):**
1. Task 1 - Core Content Implementation
2. Task 10 - Cell Selection Handling
3. Task 4 - Production-Ready Error Handling

**Medium Priority (Feature completion):**
4. Task 2 - Laundry Feature Implementation
5. Task 5 - Dynamic Cell Height Management
6. Task 3 - Core Data Model Definition

**Lower Priority (Quality & Documentation):**
7. Task 6 - Unit Test Implementation
8. Task 7 - UI Test Implementation
9. Task 8 - Project Documentation
10. Task 9 - LICENSE File Completion

### Estimated Effort

| Task | Complexity | Estimated Time |
|------|------------|----------------|
| Task 1 | High | 4-6 hours |
| Task 2 | Medium | 3-4 hours |
| Task 3 | High | 4-6 hours |
| Task 4 | Low | 1-2 hours |
| Task 5 | Low | 1-2 hours |
| Task 6 | Medium | 3-4 hours |
| Task 7 | Medium | 2-3 hours |
| Task 8 | Medium | 2-3 hours |
| Task 9 | Very Low | 5 minutes |
| Task 10 | Low | 1-2 hours |

**Total Estimated Time: 21-32 hours**

---

## Workflow Reminder

For **EACH** task above:

1. ✅ **IMPLEMENT**: Write the code changes
2. ✅ **TEST**: Verify functionality and acceptance criteria
3. ✅ **COMMIT**: Create a clear, descriptive commit
4. ✅ **DOCUMENT**: Update relevant documentation

---

## Notes

- All tasks are independent unless explicitly noted in "Affected Files"
- Some tasks build on each other (e.g., Task 3 enables better Task 1 implementation)
- Test tasks (6, 7) should be ongoing as other features are implemented
- Documentation (Task 8) should be updated incrementally with each feature

---

**Document Created**: 2025-11-15
**Last Updated**: 2025-11-15
**Status**: Initial Audit Complete
