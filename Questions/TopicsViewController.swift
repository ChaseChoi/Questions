import UIKit

class TopicsViewController: UITableViewController {
	
	// MARK: View life cycle
	@IBOutlet weak var addBarButtonItem: UIBarButtonItem!
	@IBOutlet weak var refreshBarButtonItem: UIBarButtonItem!
	@IBOutlet weak var composeBarButtonItem: UIBarButtonItem!
	@IBOutlet weak var cameraBarButtonItem: UIBarButtonItem!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		self.navigationItem.title = SetOfTopics.shared.current == .community ? "Community".localized : "Topics".localized
		self.navigationItem.backBarButtonItem?.title = "Main menu".localized
		
		self.editButtonItem.isEnabled = SetOfTopics.shared.current != .community
		if let rightBarButtonItems = self.navigationItem.rightBarButtonItems {
			self.navigationItem.rightBarButtonItems = [self.editButtonItem] + rightBarButtonItems
		}
		self.tableView.allowsMultipleSelectionDuringEditing = true
		self.clearsSelectionOnViewWillAppear = true
		
		self.isEditing = false

		let allowedBarButtonItems: [UIBarButtonItem]?
		if SetOfTopics.shared.current != .community {
			allowedBarButtonItems = self.navigationItem.rightBarButtonItems?.filter { $0 != self.refreshBarButtonItem}
		} else {
			allowedBarButtonItems = [self.addBarButtonItem, self.refreshBarButtonItem]
		}
		self.navigationItem.setRightBarButtonItems(allowedBarButtonItems, animated: false)
		
		let trashItem = UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(deleteItems))
		let flexibleSpaceItem = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: self, action: nil)
		let shareItem = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(shareItems))
		self.toolbarItems = [trashItem, flexibleSpaceItem, shareItem]
		
		if UserDefaultsManager.darkThemeSwitchIsOn {
			self.loadCurrentTheme()
		}
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		self.updateEditButton()
	}
	
	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		self.navigationController?.setToolbarHidden(true, animated: false)
		self.setEditing(false, animated: true)
	}
	
	// MARK: Edit cell, delete
	
	@objc internal func editModeAction() {
		self.setEditing(!self.isEditing, animated: true)
	}
	
	override func setEditing(_ editing: Bool, animated: Bool) {
		super.setEditing(editing, animated: animated)
		self.navigationController?.setToolbarHidden(!editing, animated: true)
		if editing { self.toolbarItems?.forEach { $0.isEnabled = false }}
	}
	
	override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
		switch indexPath.section {
		case SetOfTopics.Mode.app.rawValue: return false
		case SetOfTopics.Mode.saved.rawValue: return true
		default: return false
		}
	}
	
	override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCellEditingStyle {
		switch indexPath.section {
		case SetOfTopics.Mode.app.rawValue: return .none
		case SetOfTopics.Mode.saved.rawValue: return .delete
		default: return .none
		}
	}
	
	override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
		guard editingStyle == .delete else { return }
		
		if let cell = tableView.cellForRow(at: indexPath), let labelText = cell.textLabel?.text {
			SetOfTopics.shared.removeSavedTopics(named: [labelText], reloadAfterDeleting: true)
			tableView.deleteRows(at: [indexPath], with: .fade)
		}
	}
	
	// MARK: UITableViewDataSource
	
	@objc private func reloadTopicIfCommunityTopicsLoaded(_ timer: Timer) {
		if CommunityTopics.shared != nil && CommunityTopics.areLoaded {
			DispatchQueue.main.async {
				(self.tableView?.backgroundView as? UIActivityIndicatorView)?.stopAnimating()
				self.tableView.reloadData()
			}
			timer.invalidate()
		}
	}
	
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		
		if SetOfTopics.shared.current == .community {
			if self.tableView.backgroundView == nil && SetOfTopics.shared.communityTopics.isEmpty {
				let activityIndicatorView = UIActivityIndicatorView(activityIndicatorStyle: UserDefaultsManager.darkThemeSwitchIsOn ? .white : .gray)
				activityIndicatorView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
				activityIndicatorView.startAnimating()
				
				self.tableView?.backgroundView = activityIndicatorView
				
				if CommunityTopics.shared == nil || !CommunityTopics.areLoaded {
					
					if #available(iOS 10.0, *) {
						Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
							if CommunityTopics.shared != nil && CommunityTopics.areLoaded {
								DispatchQueue.main.async {
									activityIndicatorView.stopAnimating()
									self.tableView.reloadData()
								}
								timer.invalidate()
							}
						}
					} else {
						Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(self.reloadTopicIfCommunityTopicsLoaded), userInfo: nil, repeats: true)
					}
				}
			}
			return SetOfTopics.shared.communityTopics.count
		}
		else {
			switch section {
			case SetOfTopics.Mode.app.rawValue: return SetOfTopics.shared.topics.count
			case SetOfTopics.Mode.saved.rawValue: return SetOfTopics.shared.savedTopics.count
			default: return 0
			}
		}
	}
	
	override func numberOfSections(in tableView: UITableView) -> Int {
		if SetOfTopics.shared.current == .community {
			return 1
		} else {
			return SetOfTopics.shared.savedTopics.isEmpty ? 1 : 2
		}
	}
	
	// MARK: UITableViewDelegate
	
	override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
		cell.textLabel?.textColor = .themeStyle(dark: .white, light: .black)
		cell.tintColor = .themeStyle(dark: .orange, light: .defaultTintColor)
		//cell.backgroundColor = .themeStyle(dark: .veryDarkGray, light: .white)
		if UserDefaultsManager.darkThemeSwitchIsOn { cell.backgroundColor = .veryDarkGray }
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

		let cell = tableView.dequeueReusableCell(withIdentifier: "setCell", for: indexPath)
		
		if SetOfTopics.shared.current == .community {
			cell.textLabel?.text = SetOfTopics.shared.communityTopics[indexPath.row].displayedName.localized
		}
		else {
			switch indexPath.section {
			case SetOfTopics.Mode.app.rawValue:
				cell.textLabel?.text = SetOfTopics.shared.topics[indexPath.row].displayedName.localized
			case SetOfTopics.Mode.saved.rawValue:
				cell.textLabel?.text = SetOfTopics.shared.savedTopics[indexPath.row].displayedName.localized
			default: break
			}
		}
		
		// Load theme
		cell.textLabel?.font = .preferredFont(forTextStyle: .body)
		
		if UserDefaultsManager.darkThemeSwitchIsOn {
			let view = UIView()
			view.backgroundColor = UIColor.darkGray
			cell.selectedBackgroundView = view
		}
		
		return cell
	}
	
	override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		switch section {
		case SetOfTopics.Mode.app.rawValue: return nil
		case SetOfTopics.Mode.saved.rawValue: return "User topics".localized
		default: return nil
		}
	}
	
	override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
		guard UserDefaultsManager.darkThemeSwitchIsOn else { return } // NOTE: could change depending on your theme settings!
		let header = view as? UITableViewHeaderFooterView
		header?.textLabel?.textColor = .themeStyle(dark: .lightGray, light: .gray)
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		
		if self.isEditing { self.toolbarItems?.forEach { $0.isEnabled = true } }
		
		guard !self.isEditing, let currentCell = tableView.cellForRow(at: indexPath) else { return }
	
		if SetOfTopics.shared.current == .community {
			
			let activityIndicator = UIActivityIndicatorView(frame: currentCell.bounds)
			activityIndicator.activityIndicatorViewStyle = (UserDefaultsManager.darkThemeSwitchIsOn ? .white : .gray)
			activityIndicator.autoresizingMask = [.flexibleWidth, .flexibleHeight]
			
			if SetOfTopics.shared.communityTopics[indexPath.row].quiz.sets.flatMap({ $0 }).isEmpty,
				let communityTopics = CommunityTopics.shared {
				
				activityIndicator.startAnimating()
				currentCell.accessoryView = activityIndicator
				
				let currentTopic = communityTopics.topics[indexPath.row]
				
				DispatchQueue.global().async {
					if let validTextFromURL = try? String(contentsOf: currentTopic.remoteContentURL), let quiz = SetOfTopics.shared.quizFrom(content: validTextFromURL) {
						SetOfTopics.shared.communityTopics[indexPath.row].quiz = quiz
					}
					DispatchQueue.main.async {
						activityIndicator.stopAnimating()
						currentCell.accessoryView = nil
						self.performSegue(withIdentifier: "selectTopic", sender: indexPath)
					}
				}
				return
			}
		}
		self.performSegue(withIdentifier: "selectTopic", sender: indexPath)
	}
	
	override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
		let selectedRows = tableView.indexPathsForSelectedRows
		if self.isEditing && (selectedRows == nil || selectedRows?.isEmpty == true) {
			self.toolbarItems?.forEach { $0.isEnabled = false }
		}
	}
	
	override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
		return (self.isEditing && indexPath.section == SetOfTopics.Mode.saved.rawValue) || !self.isEditing
	}
	
	// MARK: - Actions
	
	@objc
	private func deleteItems() {
		
		guard let selectedItemsIndexPaths = self.tableView.indexPathsForSelectedRows, !selectedItemsIndexPaths.isEmpty else { return }
		
		let title = String.localizedStringWithFormat("Delete %d item%@".localized, selectedItemsIndexPaths.count, selectedItemsIndexPaths.count > 1 ? "s" : "")
		let deleteItemsAlert = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
		deleteItemsAlert.popoverPresentationController?.barButtonItem = self.toolbarItems?.first
		
		deleteItemsAlert.addAction(title: "Delete".localized, style: .destructive) { _ in
			SetOfTopics.shared.removeSavedTopics(withIndexPaths: selectedItemsIndexPaths, reloadAfterDeleting: true)
			let section = selectedItemsIndexPaths[0].section
			if self.tableView.numberOfRows(inSection: section) == selectedItemsIndexPaths.count {
				self.tableView.deleteSections([section], with: .fade)
				self.updateEditButton()
			} else {
				self.tableView.deleteRows(at: selectedItemsIndexPaths, with: .fade)
			}
			self.setEditing(false, animated: true)
		}
		deleteItemsAlert.addAction(title: "Cancel".localized, style: .cancel)
		
		self.present(deleteItemsAlert, animated: true)
	}
	
	@objc
	private func shareItems() {
		
		guard let selectedItemsIndexPaths = self.tableView.indexPathsForSelectedRows, !selectedItemsIndexPaths.isEmpty else { return }
		
		var items: [Any] = []
		
		for index in selectedItemsIndexPaths.lazy.map ({ $0.row }) {
			let quizInJSON = SetOfTopics.shared.savedTopics[index].quiz.inJSON
			items.append(quizInJSON)
			let size = min(self.view.bounds.width, self.view.bounds.height)
			if let outputQR = quizInJSON.generateQRImageWith(size: (width: size, height: size)) { items.append(outputQR) }
		}
		
		let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
		activityVC.completionWithItemsHandler = { _, completed, _, _ in
			if completed { self.setEditing(false, animated: true) }
		}
		
		activityVC.popoverPresentationController?.barButtonItem = self.toolbarItems?.last
		self.present(activityVC, animated: true)
	}
	
	@IBAction func addNewTopic(_ sender: UIBarButtonItem) {
		
		let titleText = (SetOfTopics.shared.current == .community) ? "Topic submission" : "New Topic"
		let messageText = (SetOfTopics.shared.current != .community)
			? "You can read a QR code to add a topic or download it using a URL which contains an appropiate formatted file."
			: "You can specify a URL which contains an appropiate formatted file or the full topic content."
		
		let newTopicAlert = UIAlertController(title: titleText.localized, message: messageText.localized, preferredStyle: .alert)
		
		newTopicAlert.addTextField { textField in
			textField.placeholder = "Topic Name".localized
			textField.keyboardType = .alphabet
			textField.autocapitalizationType = .sentences
			textField.autocorrectionType = .yes
			textField.keyboardAppearance = UserDefaultsManager.darkThemeSwitchIsOn ? .dark : .light
			textField.addConstraint(textField.heightAnchor.constraint(equalToConstant: 25))
		}
		
		newTopicAlert.addTextField { textField in
			textField.placeholder = "Topic URL or fomatted content".localized
			textField.keyboardType = .URL
			textField.keyboardAppearance = UserDefaultsManager.darkThemeSwitchIsOn ? .dark : .light
			textField.addConstraint(textField.heightAnchor.constraint(equalToConstant: 25))
		}
		
		newTopicAlert.addAction(title: "Help".localized, style: .default) { _ in
			if let url = URL(string: "https://github.com/illescasDaniel/Questions#topics-json-format") {
				if #available(iOS 10.0, *) {
					UIApplication.shared.open(url, options: [:])
				} else {
					UIApplication.shared.openURL(url)
				}
			}
		}
		
		let okAction = (SetOfTopics.shared.current != .community) ? "Add" : "Submit"
		newTopicAlert.addAction(title: okAction.localized, style: .default) { _ in
			
			if let topicName = newTopicAlert.textFields?.first?.text,
				let topicURLText = newTopicAlert.textFields?.last?.text, !topicURLText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
				
				self.okActionAddItem(topicName: topicName, topicURLText: topicURLText)
			}
		}
		
		newTopicAlert.addAction(title: "Cancel".localized, style: .cancel)
		
		self.present(newTopicAlert, animated: true)
	}
	
	@IBAction func refreshTopics(_ sender: UIBarButtonItem) {
		
		SetOfTopics.shared.communityTopics.removeAll(keepingCapacity: true)
		CommunityTopics.shared = nil
		self.tableView.reloadData()
		
		DispatchQueue.global().async {
			SetOfTopics.shared.loadCommunityTopics()
		}
	}
	
	@IBAction func createTopic(_ sender: UIBarButtonItem) {
		
	}
	
	@IBAction func readTopicFromCamera(_ sender: UIBarButtonItem) {
		
	}
	// MARK: - UIStoryboardSegue Handling

	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		if let topicIndexPath = sender as? IndexPath, segue.identifier == "selectTopic" {
			
			let controller = segue.destination as? QuizzesViewController
			
			if SetOfTopics.shared.current != .community {
				switch topicIndexPath.section {
				case SetOfTopics.Mode.app.rawValue: SetOfTopics.shared.current = .app
				case SetOfTopics.Mode.saved.rawValue: SetOfTopics.shared.current = .saved
				default: break
				}
			}
			controller?.currentTopicIndex = topicIndexPath.row
		}
	}
	
	// MARK: - Convenience
	
	private func updateEditButton() {
		self.editButtonItem.isEnabled = !SetOfTopics.shared.savedTopics.isEmpty
	}
	
	private func loadCurrentTheme() {
		self.tableView.backgroundColor = .themeStyle(dark: .black, light: .groupTableViewBackground)
		self.tableView.separatorColor = .themeStyle(dark: .black, light: .defaultSeparatorColor)
	}
	
	private func okActionAddItem(topicName: String, topicURLText: String) {
		
		DispatchQueue.global().async {
			
			if SetOfTopics.shared.current == .community {
				
				let messageBody = """
					Topic name: \(topicName)
					Topic URL or content: \(topicURLText)
					""".addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? "error"
				
				let devEmail = "daniel.illescas@icloud.com"
				let subject = "Questions - Topic submission".addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? "Questions_Topic submission"
				let fullURL = "mailto:\(devEmail)?subject=\(subject)&body=\(messageBody)"
				
				if let validURL = URL(string: fullURL) {
					UIApplication.shared.openURL(validURL)
				}
			}
			else {
				let quizContent: String
				if let topicURL = URL(string: topicURLText), let validTextFromURL = try? String(contentsOf: topicURL) {
					quizContent = validTextFromURL
				} else {
					quizContent = topicURLText
				}
				
				if let validQuiz = SetOfTopics.shared.quizFrom(content: quizContent) {
					SetOfTopics.shared.save(topic: TopicEntry(name: topicName, content: validQuiz))
					DispatchQueue.main.async {
						self.tableView.reloadData()
					}
				}
			}
		}
	}
}
