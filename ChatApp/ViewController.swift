import UIKit
import ApplozicSwift
class ViewController: UIViewController {

    let chatButton = UIButton()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupButton()
        self.title = "Chat"
    }
    
    func setupButton() {
        view.addSubview(chatButton)
        chatButton.addTarget(self, action: #selector(chatAction), for: .touchUpInside)
        chatButton.backgroundColor = .blue
        chatButton.setTitle("Launch chat", for: .normal)
        chatButton.layer.cornerRadius = 8
        chatButton.translatesAutoresizingMaskIntoConstraints = false
        chatButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
        chatButton.widthAnchor.constraint(equalToConstant: 240).isActive = true
        chatButton.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        chatButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -35).isActive = true
    }
    
    @objc func chatAction() {
        let conversationVC = ALKConversationListViewController(configuration: AppDelegate.config)
        let nav = ALKBaseNavigationViewController(rootViewController: conversationVC)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true, completion: nil)
    }
}
