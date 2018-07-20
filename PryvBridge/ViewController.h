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
@property (nonatomic, retain) IBOutlet UISwitch *locationSwitch;
@property (nonatomic, retain) IBOutlet UILabel *locationLabel;
@property (nonatomic, retain) IBOutlet UILabel *locationCount;

- (IBAction)locationSwitchStateChanged:(id)sender;

- (IBAction)signinButtonPressed:(id)sender;


- (IBAction)addNoteButtonPressed:(id)sender;


@end

