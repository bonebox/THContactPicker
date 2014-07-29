//
//  ContactPickerViewController.h
//  ContactPicker
//
//  Created by Tristan Himmelman on 11/2/12.
//  Copyright (c) 2012 Tristan Himmelman. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AddressBookUI/AddressBookUI.h>
#import "THContactPickerView.h"
#import "THContactPickerTableViewCell.h"

@protocol THContactPickerViewControllerDelegate;

@interface THContactPickerViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, THContactPickerDelegate, ABPersonViewControllerDelegate>

@property (nonatomic, strong) THContactPickerView *contactPickerView;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong, readonly) NSArray *contacts;
@property (nonatomic, strong, readonly) NSArray *filteredContacts;
@property (nonatomic, strong) NSArray *selectedContacts;
@property (nonatomic, strong) NSString *navTitle;

@property (nonatomic, weak) id<THContactPickerViewControllerDelegate> delegate;

@end

@protocol THContactPickerViewControllerDelegate <NSObject>

- (void)THContactPickerViewController:(THContactPickerViewController *)contactPickerViewController didDismissWithSelectedContacts:(NSArray *)selectedContacts;

@end
