//
//  EnterPhoneNumberVM.swift
//  Zuum
//
//  Created by Beny Boariu on 06/08/2016.
//  Copyright © 2016 Zuum Transportation Inc. All rights reserved.
//

import Foundation
import RxSwift
import RxCocoa

let minPhoneCount       = 11

func validatePhoneNumber(_ phone: String) -> ValidationResult {
    let numberOfCharacters = phone.count
    if numberOfCharacters < minPhoneCount {
        return .invalid(message: "Phone_Number_Too_Short".localized())
    }
    
    return .valid(message: "Phone_Accepted".localized())
}

class EnterPhoneNumberVM {
    let phoneNumberValid: Observable<ValidationResult>
    let requestCode: Observable<RequestState>
    
    //>     This will trigger a .next event, each time IQKeyboardManager Done button is tapped
    //>     We use it as hack to trigger requestCode, together with continueTap
    let subjectDoneHack             = PublishSubject<Void>()
    
    init(phone: Observable<String?>, continueTap: Observable<Void>) {
        phoneNumberValid    = phone
            .map { phone in
                return validatePhoneNumber(phone!)
        }
        
        let phoneAndValid       = Observable.combineLatest(phone, phoneNumberValid) { ($0, $1) }
        
        requestCode             = Observable.of(continueTap, subjectDoneHack.asObservable())
            .merge()
            .asObservable()
            .withLatestFrom(phoneAndValid)
            .filter { $1.isValid }
            .map { phone, _ in ZuumUtils.stripPhoneNumber(phone!) }
            .flatMapLatest { phone -> Observable<RequestState> in
                return User
                    .requestCodeForPhone(phone)
                    .startWith(.loading)
            }
            .startWith(.initial)
            .share(replay: 1)
    }
    
    deinit {
        print("EnterPhoneNumberVM deinit")
    }
}
