//
//  ViewController.h
//  PryvBridge
//
//  Created by Perki on 11.03.15.
//  Copyright (c) 2015 Pryv. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface ViewController : UIViewController {
}

@property (nonatomic, retain) IBOutlet UITableView *eventTable;
@property (nonatomic, retain) IBOutlet UIButton *addNoteButton;
@property (nonatomic, retain) IBOutlet UIButton *signinButton;
@property (nonatomic, retain) IBOutlet UIButton *locationButton;
@property (nonatomic, retain) IBOutlet UILabel *locationLabel;
@property (nonatomic, retain) IBOutlet UILabel *locationCount;

@property (nonatomic, retain) IBOutlet UIButton *healthButton;
@property (nonatomic, retain) IBOutlet UILabel *healthLabel;
@property (nonatomic, retain) IBOutlet UILabel *healthCount;

- (IBAction)locationButtonPressed:(id)sender;
- (IBAction)healthButtonPressed:(id)sender;

- (IBAction)signinButtonPressed:(id)sender;


- (IBAction)addNoteButtonPressed:(id)sender;


@end

