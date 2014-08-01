//
//  ContactPickerViewController.m
//  ContactPicker
//
//  Created by Tristan Himmelman on 11/2/12.
//  Copyright (c) 2012 Tristan Himmelman. All rights reserved.
//

#import "THContactPickerViewController.h"
#import <AddressBook/AddressBook.h>
#import "THContact.h"


@interface THContactPickerViewController ()

@property (nonatomic, strong) NSArray *contacts;
@property (nonatomic, strong) NSArray *filteredContacts;
@property (nonatomic) ABAddressBookRef addressBookRef;
@property (nonatomic, strong) UIBarButtonItem *barButton;

@end

//#define kKeyboardHeight 216.0
#define kKeyboardHeight 0.0

@implementation THContactPickerViewController

- (id)initWithPresentationStyle:(THContactPickerViewControllerPresentationStyle)presentationStyle
{
    self = [super init];
    if (self) {
        _presentationStyle = presentationStyle;
    }
    return self;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        
        CFErrorRef error;
        _addressBookRef = ABAddressBookCreateWithOptions(NULL, &error);
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    //    UIBarButtonItem * barButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonItemStyleBordered target:self action:@selector(removeAllContacts:)];

    self.barButton = [[UIBarButtonItem alloc] initWithTitle:(self.buttonTitle ?: @"Done") style:UIBarButtonItemStyleDone target:self action:@selector(done:)];
    self.barButton.enabled = self.selectedContacts.count > 0 ? YES : NO;

    if (!self.buttonLocation || self.buttonLocation == THContactPickerViewControllerButtonLocationLeft) {
        self.navigationItem.leftBarButtonItem = self.barButton;
    } else if (self.buttonLocation == THContactPickerViewControllerButtonLocationRight) {
        self.navigationItem.rightBarButtonItem = self.barButton;
    }

    self.title = [NSString stringWithFormat:@"%@ (%lu)", self.navTitle ?: @"Select Contacts", (unsigned long)self.selectedContacts.count];

    // Initialize and add Contact Picker View
    self.contactPickerView = [[THContactPickerView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 100)];
    self.contactPickerView.delegate = self;
    [self.contactPickerView setPlaceholderString:@"Type contact name"];
    [self.view addSubview:self.contactPickerView];
    
    // Fill the rest of the view with the table view
    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, self.contactPickerView.frame.size.height, self.view.frame.size.width, self.view.frame.size.height - self.contactPickerView.frame.size.height - kKeyboardHeight) style:UITableViewStylePlain];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    
    [self.tableView registerNib:[UINib nibWithNibName:@"THContactPickerTableViewCell" bundle:nil] forCellReuseIdentifier:@"ContactCell"];

    self.tableView.translatesAutoresizingMaskIntoConstraints = YES;
    
    [self.view insertSubview:self.tableView belowSubview:self.contactPickerView];
    
    ABAddressBookRequestAccessWithCompletion(self.addressBookRef, ^(bool granted, CFErrorRef error) {
        if (granted) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self getContactsFromAddressBook];
            });
        } else {
            // TODO: Show alert
        }
    });
}

-(void)getContactsFromAddressBook
{
    CFErrorRef error = NULL;
    self.contacts = [[NSMutableArray alloc] init];
    
    ABAddressBookRef addressBook = ABAddressBookCreateWithOptions(NULL, &error);
    if (addressBook) {
        ABRecordRef source = ABAddressBookCopyDefaultSource(addressBook);
        NSArray *allContacts = (__bridge_transfer NSArray *)ABAddressBookCopyArrayOfAllPeopleInSourceWithSortOrdering(addressBook, source, kABPersonSortByLastName);

        NSMutableArray *updatedContacts = [NSMutableArray array];
        NSMutableSet *linkedPeopleToSkip = [NSMutableSet set];

        [allContacts enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {

            if (![linkedPeopleToSkip containsObject:obj]) {
                NSArray *linkedPeople = (__bridge_transfer NSArray *)ABPersonCopyArrayOfAllLinkedPeople((__bridge ABRecordRef)obj);
                if (linkedPeople.count > 1) {
                    [linkedPeopleToSkip addObjectsFromArray:linkedPeople];
                }
                [updatedContacts addObject:obj];
            }
        }];

        NSMutableArray *mutableContacts = [NSMutableArray array];

        [updatedContacts enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {

            ABRecordRef contactPerson = (__bridge ABRecordRef)obj;
            
            // Get mobile number
            ABMultiValueRef phonesRef = ABRecordCopyValue(contactPerson, kABPersonPhoneProperty);

            for (int i=0; i < ABMultiValueGetCount(phonesRef); i++) {
                CFStringRef currentPhoneValue = ABMultiValueCopyValueAtIndex(phonesRef, i);
                CFStringRef currentPhoneLabel = ABMultiValueCopyLabelAtIndex(phonesRef, i);
                CFStringRef localizedLabel = ABAddressBookCopyLocalizedLabel(currentPhoneLabel);

                THContact *contact = [[THContact alloc] init];
                contact.recordId = ABRecordGetRecordID(contactPerson);

                // Get first and last names
                NSString *firstName = (__bridge_transfer NSString*)ABRecordCopyValue(contactPerson, kABPersonFirstNameProperty);
                NSString *lastName = (__bridge_transfer NSString*)ABRecordCopyValue(contactPerson, kABPersonLastNameProperty);

                // If no first or last name, set first name to organization
                if (!firstName && !lastName) {
                    firstName = (__bridge_transfer NSString*)ABRecordCopyValue(contactPerson, kABPersonOrganizationProperty);
                }
                // Set Contact properties
                contact.firstName = firstName;
                contact.lastName = lastName;

                contact.phone = (__bridge NSString *)currentPhoneValue ?: @"";
                contact.phoneLabel = (__bridge NSString *)localizedLabel ?: @"";

                // Get image if it exists
                NSData  *imgData = (__bridge_transfer NSData *)ABPersonCopyImageData(contactPerson);
                contact.image = [UIImage imageWithData:imgData];
                if (!contact.image) {
                    contact.image = [UIImage imageNamed:@"icon-avatar-60x60"];
                }

                [mutableContacts addObject:contact];
            }

            if(phonesRef) {
                CFRelease(phonesRef);
            }
        }];

        if(addressBook) {
            CFRelease(addressBook);
        }
        
        self.contacts = [NSArray arrayWithArray:mutableContacts];
        self.filteredContacts = self.contacts;

        if (self.selectedContacts) {
            [self.selectedContacts enumerateObjectsUsingBlock:^(THContact *user, NSUInteger idx, BOOL *stop) {
                [self.contactPickerView addContact:user withName:user.fullName];
            }];
        } else {
            self.selectedContacts = [NSMutableArray array];
        }

        [self.tableView reloadData];
    }
    else
    {
        NSLog(@"Error");
    }
}

- (NSString *)getMobilePhoneProperty:(ABMultiValueRef)phonesRef
{
    for (int i=0; i < ABMultiValueGetCount(phonesRef); i++) {
        CFStringRef currentPhoneLabel = ABMultiValueCopyLabelAtIndex(phonesRef, i);
        CFStringRef currentPhoneValue = ABMultiValueCopyValueAtIndex(phonesRef, i);
        
        if(currentPhoneLabel) {
            if (CFStringCompare(currentPhoneLabel, kABPersonPhoneMobileLabel, 0) == kCFCompareEqualTo) {
                return (__bridge NSString *)currentPhoneValue;
            }
            
            if (CFStringCompare(currentPhoneLabel, kABHomeLabel, 0) == kCFCompareEqualTo) {
                return (__bridge NSString *)currentPhoneValue;
            }
        }
        if(currentPhoneLabel) {
            CFRelease(currentPhoneLabel);
        }
        if(currentPhoneValue) {
            CFRelease(currentPhoneValue);
        }
    }
    
    return nil;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    dispatch_async(dispatch_get_main_queue(), ^{
//        [self refreshContacts];
    });
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat topOffset = 0;
    if ([self respondsToSelector:@selector(topLayoutGuide)]){
        topOffset = self.topLayoutGuide.length;
    }
    CGRect frame = self.contactPickerView.frame;
    frame.origin.y = topOffset;
    self.contactPickerView.frame = frame;
    [self adjustTableViewFrame:NO];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)adjustTableViewFrame:(BOOL)animated {
    CGRect frame = self.tableView.frame;
    // This places the table view right under the text field
    frame.origin.y = self.contactPickerView.frame.size.height;
    // Calculate the remaining distance
    frame.size.height = self.view.frame.size.height - self.contactPickerView.frame.size.height - kKeyboardHeight;
    
    if(animated) {
        [UIView beginAnimations:nil context:nil];
        [UIView setAnimationDuration:0.3];
        [UIView setAnimationDelay:0.1];
        [UIView setAnimationCurve:UIViewAnimationCurveEaseOut];
        
        self.tableView.frame = frame;
        
        [UIView commitAnimations];
    }
    else{
        self.tableView.frame = frame;
    }
}



#pragma mark - UITableView Delegate and Datasource functions

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.filteredContacts.count;
}

- (CGFloat)tableView: (UITableView*)tableView heightForRowAtIndexPath: (NSIndexPath*) indexPath {
    return 70;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    // Get the desired contact from the filteredContacts array
    THContact *contact = [self.filteredContacts objectAtIndex:indexPath.row];
    
    // Initialize the table view cell
    NSString *cellIdentifier = @"ContactCell";
    THContactPickerTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil){
        cell = (THContactPickerTableViewCell *)[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
    }

    // Assign values to to US elements
    cell.name.text = [contact fullName];
    cell.phone.text = contact.phone;
    cell.phoneLabel.text = contact.phoneLabel;

    if(contact.image) {
        cell.avatar.image = contact.image;
    }
    cell.avatar.layer.masksToBounds = YES;
    cell.avatar.layer.cornerRadius = 20;
    
    // Set the checked state for the contact selection checkbox
    UIImage *image;

    if ([self.selectedContacts containsObject:contact]){
        //cell.accessoryType = UITableViewCellAccessoryCheckmark;
        image = [UIImage imageNamed:@"icon-checkbox-selected-green-25x25"];
    } else {
        //cell.accessoryType = UITableViewCellAccessoryNone;
        image = [UIImage imageNamed:@"icon-checkbox-unselected-25x25"];
    }
    cell.checkbox.image = image;
    
    // Assign a UIButton to the accessoryView cell property
//    cell.accessoryView = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];
    // Set a target and selector for the accessoryView UIControlEventTouchUpInside
//    [(UIButton *)cell.accessoryView addTarget:self action:@selector(viewContactDetail:) forControlEvents:UIControlEventTouchUpInside];
//    cell.accessoryView.tag = contact.recordId; //so we know which ABRecord in the IBAction method

    // // For custom accessory view button use this.
    //    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    //    button.frame = CGRectMake(0.0f, 0.0f, 150.0f, 25.0f);
    //
    //    [button setTitle:@"Expand"
    //            forState:UIControlStateNormal];
    //
    //    [button addTarget:self
    //               action:@selector(viewContactDetail:)
    //     forControlEvents:UIControlEventTouchUpInside];
    //
    //    cell.accessoryView = button;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // Hide Keyboard
    [self.contactPickerView resignKeyboard];
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    THContactPickerTableViewCell *cell = (THContactPickerTableViewCell *)[tableView cellForRowAtIndexPath:indexPath];
    
    // This uses the custom cellView
    // Set the custom imageView
    THContact *user = [self.filteredContacts objectAtIndex:indexPath.row];

    UIImage *image;
    
    if ([self.selectedContacts containsObject:user]){ // contact is already selected so remove it from ContactPickerView
        //cell.accessoryType = UITableViewCellAccessoryNone;
        NSUInteger index = [self.selectedContacts indexOfObject:user];
        THContact *contact = [self.selectedContacts objectAtIndex:index];
        [self.contactPickerView removeContact:contact];

        NSMutableArray *updateContacts = [self.selectedContacts mutableCopy];
        [updateContacts removeObject:user];
        self.selectedContacts = [NSArray arrayWithArray:updateContacts];
        // Set checkbox to "unselected"
        image = [UIImage imageNamed:@"icon-checkbox-unselected-25x25"];
    } else {
        // Contact has not been selected, add it to THContactPickerView
        //cell.accessoryType = UITableViewCellAccessoryCheckmark;
        NSMutableArray *updateContacts = [self.selectedContacts mutableCopy];
        [updateContacts addObject:user];
        self.selectedContacts = [NSArray arrayWithArray:updateContacts];
        [self.contactPickerView addContact:user withName:user.fullName];
        // Set checkbox to "selected"
        image = [UIImage imageNamed:@"icon-checkbox-selected-green-25x25"];
    }
    
    // Enable Done button if total selected contacts > 0
    if(self.selectedContacts.count > 0) {
        self.barButton.enabled = TRUE;
    }
    else
    {
        self.barButton.enabled = FALSE;
    }
    
    // Update window title
    self.title = [NSString stringWithFormat:@"%@ (%lu)", self.navTitle ?: @"Select Contacts", (unsigned long)self.selectedContacts.count];
    
    // Set checkbox image
    cell.checkbox.image = image;
    // Reset the filtered contacts
    self.filteredContacts = self.contacts;
    // Refresh the tableview
    [self.tableView reloadData];
}

#pragma mark - THContactPickerTextViewDelegate

- (void)contactPickerTextViewDidChange:(NSString *)textViewText {
    if ([textViewText isEqualToString:@""]){
        self.filteredContacts = self.contacts;
    } else {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"self.%@ contains[cd] %@ OR self.%@ contains[cd] %@", @"firstName", textViewText, @"lastName", textViewText];
        self.filteredContacts = [self.contacts filteredArrayUsingPredicate:predicate];
    }
    [self.tableView reloadData];
}

- (void)contactPickerDidResize:(THContactPickerView *)contactPickerView {
    [self adjustTableViewFrame:YES];
}

- (void)contactPickerDidRemoveContact:(id)contact {
    NSMutableArray *updateContacts = [self.selectedContacts mutableCopy];
    [updateContacts removeObject:contact];
    self.selectedContacts = [NSArray arrayWithArray:updateContacts];

    NSUInteger index = [self.contacts indexOfObject:contact];
    THContactPickerTableViewCell *cell = (THContactPickerTableViewCell *)[self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0]];
    //cell.accessoryType = UITableViewCellAccessoryNone;
    
    // Enable Done button if total selected contacts > 0
    if(self.selectedContacts.count > 0) {
        self.barButton.enabled = TRUE;
    }
    else
    {
        self.barButton.enabled = FALSE;
    }
    
    // Set unchecked image
    UIImage *image;
    image = [UIImage imageNamed:@"icon-checkbox-unselected-25x25"];
    cell.checkbox.image = image;
    
    // Update window title
    self.title = [NSString stringWithFormat:@"%@ (%lu)", self.navTitle ?: @"Select Contacts", (unsigned long)self.selectedContacts.count];
}

- (void)removeAllContacts:(id)sender
{
    [self.contactPickerView removeAllContacts];
    self.selectedContacts = @[];
    self.filteredContacts = self.contacts;
    [self.tableView reloadData];
}
#pragma mark ABPersonViewControllerDelegate

- (BOOL)personViewController:(ABPersonViewController *)personViewController shouldPerformDefaultActionForPerson:(ABRecordRef)person property:(ABPropertyID)property identifier:(ABMultiValueIdentifier)identifier
{
    return YES;
}

// This opens the apple contact details view: ABPersonViewController
//TODO: make a THContactPickerDetailViewController
- (IBAction)viewContactDetail:(UIButton*)sender {
    ABRecordID personId = (ABRecordID)sender.tag;
    ABPersonViewController *view = [[ABPersonViewController alloc] init];
    view.addressBook = self.addressBookRef;
    view.personViewDelegate = self;
    view.displayedPerson = ABAddressBookGetPersonWithRecordID(self.addressBookRef, personId);

    
    [self.navigationController pushViewController:view animated:YES];
}

- (IBAction)done:(id)sender
{
    if (self.didTapDone)
        self.didTapDone(self.selectedContacts);

    if (self.presentationStyle == THContactPickerViewControllerPresentationStyleModal) {
        __weak __typeof(&*self) weakSelf = self;
        [self.navigationController dismissViewControllerAnimated:YES completion:^{
            if ([weakSelf.delegate respondsToSelector:@selector(THContactPickerViewController:didDismissWithSelectedContacts:)]) {
                [weakSelf.delegate performSelector:@selector(THContactPickerViewController:didDismissWithSelectedContacts:) withObject:weakSelf withObject:weakSelf.selectedContacts];
            }
        }];
    }
}

@end
