// NEWG Launcher pilot. Copyright 2026 NEWG contributors. AGPL-3.0-only.
@preconcurrency import UIKit
import UniformTypeIdentifiers

@available(iOS 15.0, *)
@MainActor
final class NEWGHomeViewController: UIViewController, UIDocumentPickerDelegate {
    var showMyApps: (() -> Void)?
    var renewApps: (() -> Void)?
    private var release: NEWGRelease?
    private var download: NEWGDownload?
    private let status = UILabel()
    private let releaseLabel = UILabel()
    private let downloadProgress = UIProgressView(progressViewStyle: .default)
    private var installButton = UIButton(type: .system)
    private var cancelButton = UIButton(type: .system)
    private var setupButton = UIButton(type: .system)
    private var renewButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "NEWG Launcher"
        view.backgroundColor = .systemGroupedBackground
        let scroll = UIScrollView()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        scroll.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -24),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -48)
        ])
        stack.addArrangedSubview(label("ROS NEW GENERATION", style: .largeTitle))
        stack.addArrangedSubview(label("Owner phone pilot · powered by SideStore", style: .subheadline))
        stack.addArrangedSubview(label("Set up your own Apple Account, turn on LocalDevVPN, then refresh the launcher before installing ROS.", style: .body))
        setupButton = button("Apple Account setup", symbol: "person.crop.circle", action: #selector(signIn))
        stack.addArrangedSubview(setupButton)
        renewButton = button("Renew launcher and apps", symbol: "arrow.clockwise", action: #selector(renew))
        stack.addArrangedSubview(renewButton)
        stack.addArrangedSubview(button("My apps and expiry dates", symbol: "clock", action: #selector(myApps)))
        releaseLabel.numberOfLines = 0
        releaseLabel.font = .preferredFont(forTextStyle: .headline)
        stack.addArrangedSubview(releaseLabel)
        installButton = button("Install / update ROS", symbol: "arrow.down.circle.fill", action: #selector(installROS))
        stack.addArrangedSubview(installButton)
        downloadProgress.accessibilityLabel = "ROS download progress"
        downloadProgress.isHidden = true
        stack.addArrangedSubview(downloadProgress)
        cancelButton = button("Cancel download", symbol: "xmark.circle", action: #selector(cancelDownload))
        cancelButton.isHidden = true
        stack.addArrangedSubview(cancelButton)
        status.numberOfLines = 0
        status.font = .preferredFont(forTextStyle: .body)
        status.accessibilityIdentifier = "newgStatus"
        stack.addArrangedSubview(status)
        stack.addArrangedSubview(button("Import NEWG release file", symbol: "doc.badge.plus", action: #selector(importRelease)))
        stack.addArrangedSubview(label("Free personal signing lasts 7 days. Initial PC pairing is required. Pairing recovery or an expired launcher may require the PC again. Your Apple Account is handled by the on-device SideStore engine, not the NEWG website.", style: .footnote))
        stack.addArrangedSubview(button("NEWG portal", symbol: "globe", action: #selector(openPortal)))
        stack.addArrangedSubview(button("Source code and license", symbol: "chevron.left.forwardslash.chevron.right", action: #selector(openSource)))
        loadRelease()
        updateState()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateState()
    }

    private func label(_ text: String, style: UIFont.TextStyle) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .preferredFont(forTextStyle: style)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        return label
    }

    private func button(_ title: String, symbol: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.image = UIImage(systemName: symbol)
        configuration.imagePadding = 10
        configuration.baseBackgroundColor = .systemRed
        configuration.contentInsets = .init(top: 16, leading: 16, bottom: 16, trailing: 16)
        button.configuration = configuration
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private var cachedReleaseURL: URL {
        FileManager.default.documentsDirectory.appendingPathComponent("NEWGRelease.json")
    }

    private func loadRelease() {
        if let values = try? cachedReleaseURL.resourceValues(forKeys: [.fileSizeKey]),
           (values.fileSize ?? Int.max) <= 65_536,
           let data = try? Data(contentsOf: cachedReleaseURL), let item = try? NEWGRelease.decode(data) {
            release = item
        } else if let dictionary = Bundle.main.object(forInfoDictionaryKey: "NEWGGameRelease") as? [String: Any],
                  let data = try? JSONSerialization.data(withJSONObject: dictionary),
                  let item = try? NEWGRelease.decode(data) {
            release = item
        }
        releaseLabel.text = release.map { "ROS \($0.version) · \(ByteCountFormatter.string(fromByteCount: $0.size, countStyle: .file))" }
            ?? "Import a NEWG release file to install ROS."
    }

    private func updateState() {
        let signedIn = DatabaseManager.shared.activeAccount() != nil
        setupButton.configuration?.title = signedIn ? "Apple Account connected" : "Apple Account setup"
        installButton.isEnabled = release != nil && download == nil
        renewButton.isEnabled = download == nil
        if download == nil && status.text == nil {
            status.text = signedIn ? "Refresh the launcher first, then test ROS installation." : "Start with Apple Account setup and initial PC pairing."
        }
    }

    @objc private func signIn() {
        AppManager.shared.signIn(presentingViewController: self) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success: self.status.text = "Apple Account connected. Turn on LocalDevVPN, then renew the launcher."
                case .failure(let error) where error is CancellationError || (error as NSError).domain == CancellationError()._domain:
                    self.status.text = "Sign-in cancelled. Apple Account is not connected."
                case .failure(let error): self.status.text = error.localizedDescription
                }
                self.updateState()
            }
        }
    }

    @objc private func renew() { renewApps?() }
    @objc private func myApps() { showMyApps?() }

    @objc private func installROS() {
        guard let release, download == nil else { return }
        guard DatabaseManager.shared.activeAccount() != nil else { signIn(); return }
        let confirmation = UIAlertController(title: "Install ROS \(release.version)?",
            message: "This downloads the full IPA, verifies it, then opens the native signing/install confirmation. Keep enough storage for unpacking and signing. Keep your existing ROS installed to preserve its data.", preferredStyle: .alert)
        confirmation.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        confirmation.addAction(UIAlertAction(title: "Download", style: .default) { [weak self] _ in self?.beginDownload(release) })
        present(confirmation, animated: true)
    }

    private func beginDownload(_ release: NEWGRelease) {
        status.text = "Downloading ROS…"
        downloadProgress.progress = 0
        downloadProgress.isHidden = false
        cancelButton.isHidden = false
        let task = NEWGDownload(release: release, progress: { [weak self] progress in
            Task { @MainActor in
                self?.downloadProgress.progress = Float(progress)
                self?.status.text = progress < 1 ? "Downloading ROS · \(Int(progress * 100))%" : "Verifying the complete IPA…"
            }
        }, completion: { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                self.download = nil
                self.cancelButton.isHidden = true
                self.downloadProgress.isHidden = true
                self.updateState()
                switch result {
                case .success(let file):
                    self.status.text = "IPA verified. Continue in the signing/install confirmation."
                    NotificationCenter.default.post(name: AppDelegate.importAppDeepLinkNotification, object: nil,
                        userInfo: [AppDelegate.importAppDeepLinkURLKey: file])
                case .failure(let error): self.status.text = error.localizedDescription
                }
            }
        })
        download = task
        updateState()
        task.start()
    }

    @objc private func cancelDownload() { download?.cancel() }

    @objc private func importRelease() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.json], asCopy: true)
        picker.delegate = self
        present(picker, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard download == nil, let url = urls.first else { return }
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        do {
            let values = try url.resourceValues(forKeys: [.fileSizeKey])
            guard (values.fileSize ?? Int.max) <= 65_536 else { throw NEWGReleaseError.invalidManifest }
            let data = try Data(contentsOf: url)
            let item = try NEWGRelease.decode(data)
            try data.write(to: cachedReleaseURL, options: [.atomic, .completeFileProtectionUnlessOpen])
            release = item
            loadRelease()
            status.text = "ROS \(item.version) release ready."
            updateState()
        } catch { status.text = error.localizedDescription }
    }

    @objc private func openPortal() { UIApplication.shared.open(URL(string: "https://rosnewgen.com")!) }
    @objc private func openSource() { UIApplication.shared.open(URL(string: "https://github.com/dvshaoo/newg-launcher")!) }
}
