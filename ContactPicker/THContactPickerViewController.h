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

typedef NS_ENUM(NSUInteger, THContactPickerViewControllerPresentationStyle) {
    THContactPickerViewControllerPresentationStyleModal,
    THContactPickerViewControllerPresentationStylePush,
};

typedef NS_ENUM(NSUInteger, THContactPickerViewControllerButtonLocation) {
    THContactPickerViewControllerButtonLocationLeft,
    THContactPickerViewControllerButtonLocationRight,
    THContactPickerViewControllerButtonLocationNone,
};

typedef void (^THContactPickerViewControllerBlock)(NSArray *contacts);

@protocol THContactPickerViewControllerDelegate;

@interface THContactPickerViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, THContactPickerDelegate, ABPersonViewControllerDelegate>

@property (nonatomic, strong) THContactPickerView *contactPickerView;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong, readonly) NSArray *contacts;
@property (nonatomic, strong, readonly) NSArray *filteredContacts;
@property (nonatomic, strong) NSArray *selectedContacts;
@property (nonatomic, copy) NSString *navTitle;
@property (nonatomic, copy) NSString *buttonTitle;
@property (nonatomic) THContactPickerViewControllerPresentationStyle presentationStyle;
@property (nonatomic) THContactPickerViewControllerButtonLocation buttonLocation;
@property (nonatomic) BOOL hidesBackButton;

@property (nonatomic, copy) THContactPickerViewControllerBlock didTapDone;
@property (nonatomic, weak) id<THContactPickerViewControllerDelegate> delegate;

- (id)initWithPresentationStyle:(THContactPickerViewControllerPresentationStyle)presentationStyle;

- (IBAction)done:(id)sender;

@end

@protocol THContactPickerViewControllerDelegate <NSObject>

- (void)THContactPickerViewController:(THContactPickerViewController *)contactPickerViewController didDismissWithSelectedContacts:(NSArray *)selectedContacts;

@end
