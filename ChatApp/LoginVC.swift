import UIKit
import Applozic

class LoginVC: UIViewController {
    let userName = UITextField()
    let password = UITextField()
    let emailName = UITextField()
    let signInBarButtonItem = UIBarButtonItem(title: "Sign Up", style: .done, target: self, action: #selector(loginAction))
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUserTextField()
        setupEmail()
        setupPassword()
        self.navigationItem.rightBarButtonItem  = signInBarButtonItem
    }
    
    func setupUserTextField() {
        view.addSubview(userName)
        userName.placeholder = "Choose a username"
        userName.font = UIFont.systemFont(ofSize: 15)
        userName.borderStyle = UITextField.BorderStyle.roundedRect
        userName.autocorrectionType = UITextAutocorrectionType.no
        userName.keyboardType = UIKeyboardType.default
        userName.returnKeyType = UIReturnKeyType.done
        userName.translatesAutoresizingMaskIntoConstraints = false
        userName.heightAnchor.constraint(equalToConstant: 50).isActive = true
        userName.widthAnchor.constraint(equalToConstant: 270).isActive = true
        userName.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        userName.topAnchor.constraint(equalTo: view.topAnchor, constant: 120).isActive = true
    }
    
    func setupEmail() {
        view.addSubview(emailName)
        emailName.placeholder = "Email"
        emailName.font = UIFont.systemFont(ofSize: 15)
        emailName.borderStyle = UITextField.BorderStyle.roundedRect
        emailName.autocorrectionType = UITextAutocorrectionType.no
        emailName.keyboardType = UIKeyboardType.default
        emailName.returnKeyType = UIReturnKeyType.done
        emailName.translatesAutoresizingMaskIntoConstraints = false
        emailName.heightAnchor.constraint(equalToConstant: 50).isActive = true
        emailName.widthAnchor.constraint(equalToConstant: 270).isActive = true
        emailName.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        emailName.topAnchor.constraint(equalTo: userName.bottomAnchor, constant: 25).isActive = true
    }
    
    func setupPassword() {
        view.addSubview(password)
        password.placeholder = "Password"
        password.font = UIFont.systemFont(ofSize: 15)
        password.borderStyle = UITextField.BorderStyle.roundedRect
        password.isSecureTextEntry = true
        password.autocorrectionType = UITextAutocorrectionType.no
        password.keyboardType = UIKeyboardType.default
        password.returnKeyType = UIReturnKeyType.done
        password.translatesAutoresizingMaskIntoConstraints = false
        password.heightAnchor.constraint(equalToConstant: 50).isActive = true
        password.widthAnchor.constraint(equalToConstant: 270).isActive = true
        password.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        password.topAnchor.constraint(equalTo: emailName.bottomAnchor, constant: 25).isActive = true
    }
   
    @objc func loginAction() {
        let alUser : ALUser =  ALUser()
        alUser.applicationId = "382c2dcb1c60b63293f95a9d2f9d9709d"
        alUser.userId = userName.text
        alUser.email = emailName.text
        alUser.displayName = userName.text
        alUser.password = password.text
        ALUserDefaultsHandler.setUserId(alUser.userId)
        ALUserDefaultsHandler.setEmailId(alUser.email)
        ALUserDefaultsHandler.setDisplayName(alUser.displayName)
        ALUserDefaultsHandler.setUserAuthenticationTypeId(Int16(APPLOZIC.rawValue))
        let chatManager = ALChatManager(applicationKey: "382c2dcb1c60b63293f95a9d2f9d9709d")
        chatManager.connectUser(alUser, completion: {response, error in
                    if error == nil {
                        print("Error while logging \(error)")
                    } else {
                        let vc = ViewController()
                        self.navigationController?.pushViewController(vc, animated: true)
                        print("Successfull login")
                    }
                })
    }
}
