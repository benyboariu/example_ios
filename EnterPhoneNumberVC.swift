//
//  EnterPhoneNumberVC.swift
//  Zuum
//
//  Created by Beny Boariu on 04/08/2016.
//  Copyright © 2016 Zuum Transportation Inc. All rights reserved.
//

import UIKit
import Alamofire
import KVNProgress
import RxSwift
import RxCocoa
import SDVersion
import Async

class EnterPhoneNumberVC: ZuumCallVC {

    @IBOutlet weak var txfMobileNumber: PhoneTextField!
    @IBOutlet weak var constBtnContinueBottom: NSLayoutConstraint!
    @IBOutlet weak var btnContinue: KernButton!
    @IBOutlet weak var btnHavingTrouble: UIButton!
    
    var phoneFormatter      = PhoneNumberFormatter()
    let disposeBag          = DisposeBag()

    var viewModel: EnterPhoneNumberVM!
    
    // MARK: - ViewController Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        
        viewModel           = EnterPhoneNumberVM(phone: txfMobileNumber.rx.text.asObservable(), continueTap: btnContinue.rx.tap.asObservable())
        setupRxSwift()
        
        txfMobileNumber.keyboardToolbar.doneBarButton .setTarget(self, action: #selector(EnterPhoneNumberVC.doneAction))
        
        setupUI()
        setupTapGestureForDismissKeyboard()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        NotificationCenter.default.addObserver(self, selector: #selector(EnterPhoneNumberVC.textFieldTextDidChange), name: NSNotification.Name.UITextFieldTextDidChange, object: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        txfMobileNumber.becomeFirstResponder()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Notification Methods
    
    @objc func textFieldTextDidChange() {
        if let text = txfMobileNumber.text {
            txfMobileNumber.text                    = phoneFormatter.format(text, local: 0)
            
            if text.length == 1 {
                #if DEBUG
                    txfMobileNumber.text            = phoneFormatter.format("4 " + text, local: 0)
                #else
                    txfMobileNumber.text            = phoneFormatter.format("1 " + text, local: 0)
                #endif
            }
        }
    }
    
    // MARK: - Custom Methods
    
    func setupRxSwift() {
        viewModel.requestCode
            .subscribe(onNext: { [unowned self] requestState in
                switch requestState {
                case .initial:
                    print("UserRequestCode API Initialized")
                    
                case .loading:
                    KVNProgress.show(withStatus: "Sending".localized())
                    
                case .completed(let result):
                    if let verifyPhoneNumberVC = NavigationManager.viewControllerFromLoginStoryBoard("VerifyPhoneNumberVC") as? VerifyPhoneNumberVC {
                        verifyPhoneNumberVC.strPhoneNumber      = self.txfMobileNumber.text
                        
                        #if DEBUG || ADHOC
                            if let activationCode = result.data!["activationCode"].string {
                                verifyPhoneNumberVC.strCode = activationCode
                            }
                        #else
                            let strPhoneNumber          = ZuumUtils.stripPhoneNumber(self.txfMobileNumber.text!)
                            
                            //>-----------------------------------------------------------------------------------------------
                            //>     This is a special case for Apple testers: they will test with this number, and they
                            //>     will see the code completed for them automatically, not via Twillio
                            //>-----------------------------------------------------------------------------------------------
                            if strPhoneNumber == "10753017120" {
                                if let activationCode = result.data!["activationCode"].string {
                                    verifyPhoneNumberVC.strCode = activationCode
                                }
                            }
                        #endif
                        
                        self.navigationController?.pushViewController(verifyPhoneNumberVC, animated: true)
                    }
                    
                    KVNProgress.dismiss()
                    
                case .error(let result):
                    //>-----------------------------------------------------------------------------------------------
                    //>     Custom error: 401 - when a FleetManager account was created, but was not yet approved
                    //>     In this case, we will bring user to Pending Approval screen
                    //>-----------------------------------------------------------------------------------------------
                    if let errorCode = result.errorCode, errorCode == 401 {
                        let okAlert     = ZuumUtils.okAlertController("Oops".localized(), message: result.message)
                        
                        self.present(okAlert, animated: true, completion: { 
                            Async.main(after: 0.2) {
                                self.showPendingApprovalScreen()
                            }
                        })
                    }
                    else {
                        let okAlert     = ZuumUtils.okAlertController("Oops".localized(), message: result.message)
                        self.present(okAlert, animated: true, completion: nil)
                    }
                    
                    KVNProgress.dismiss()
                    
                case .fatalError(let message):
                    let okAlert     = ZuumUtils.okAlertController("Oops".localized(), message: message)
                    self.present(okAlert, animated: true, completion: nil)
                    
                    KVNProgress.dismiss()
                }
                })
            .disposed(by: disposeBag)
        
        viewModel.phoneNumberValid.asDriver(onErrorJustReturn: .invalid(message: ""))
            .map { $0.isValid }
            .drive(btnContinue.rx.isEnabled)
            .disposed(by: disposeBag)
        
        viewModel.phoneNumberValid.asDriver(onErrorJustReturn: .invalid(message: ""))
            .map { $0.isValid ? 1.0 : 0.5 }
            .drive(btnContinue.rx.alpha)
            .disposed(by: disposeBag)
    }
    
    func setupUI() {
        self.setNavigationTitle("Enter_Phone_Number".localized(), kern: 0.5)
        
        txfMobileNumber.layer.cornerRadius          = 4.0
        txfMobileNumber.layer.masksToBounds         = true
        txfMobileNumber.layer.borderColor           = UIColor.zuumDarkGrey().cgColor
        txfMobileNumber.layer.borderWidth           = 0.5
        
        #if DEBUG
            txfMobileNumber.text                    = phoneFormatter.format("40753017120", local: 0)
        #endif

        let dictAttributes                          = [NSAttributedStringKey.underlineStyle: NSUnderlineStyle.styleDouble.rawValue,
                                                       NSAttributedStringKey.foregroundColor: UIColor.zuumDarkGrey(),
                                                       NSAttributedStringKey.font: UIFont.latoLightOfSize(13)] as [NSAttributedStringKey : Any]
        
        let underlineAttributedString = NSAttributedString(string: "Having_Trouble".localized(), attributes: dictAttributes)
        btnHavingTrouble.setAttributedTitle(underlineAttributedString, for: .normal)
    }
    
    func setupTapGestureForDismissKeyboard() {
        let tapGestureDismissKeyboard               = UITapGestureRecognizer(target: self, action: #selector(EnterPhoneNumberVC.dismissKeyboard))
        view.addGestureRecognizer(tapGestureDismissKeyboard)
    }
    
    @objc func dismissKeyboard() {
        txfMobileNumber.resignFirstResponder()
        constBtnContinueBottom.constant             = 0
    }
    
    fileprivate func showPendingApprovalScreen() {
        if let pendingApprovalVC = NavigationManager.viewControllerFromLoginStoryBoard("PendingApprovalVC") as? PendingApprovalVC {
            self.navigationController?.pushViewController(pendingApprovalVC, animated: true)
        }
    }
    
    // MARK: - Action Methods
    
    @objc func doneAction() {
        viewModel.subjectDoneHack.onNext(())
    }
    
    @IBAction func btnHavingTrouble_Action(_ sender: AnyObject) {
        #if DEBUG || ADHOC
            txfMobileNumber.text                    = phoneFormatter.format("40753017120", local: 0)
        #endif
        
        sendEmail(emails: [Constants.ContactZuum.k_EmailAddres])
    }
    
    @IBAction func btnContinue_Action(_ sender: AnyObject) {
        
    }
    
    // MARK: - MemoryManagement Methods
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}
