import SwiftData
import SwiftUI

/// The owner's personal details. Each field is encrypted individually; sensitive
/// identifiers are masked and only revealed after Face ID / passcode.
struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    @State private var isEditing = false
    @State private var fullName = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var address = ""
    @State private var hasDOB = false
    @State private var dateOfBirth = Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()
    @State private var nationalID = ""
    @State private var employer = ""
    @State private var monthlyIncome: Decimal?

    private static let dobFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        Form {
            if isEditing {
                editForm
            } else {
                readOnly
            }
        }
        .navigationTitle("Profile")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if isEditing {
                    Button("Save", action: save).bold()
                } else {
                    Button("Edit") {
                        Task {
                            // Re-verify the owner before exposing every field unmasked.
                            if await AppLockManager.authenticate(reason: "Edit your personal details", allowWithoutPasscode: true) {
                                load()
                                isEditing = true
                            }
                        }
                    }
                }
            }
            if isEditing {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { isEditing = false } }
            }
        }
    }

    @ViewBuilder
    private var readOnly: some View {
        Section {
            HStack(spacing: 14) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(.tint)
                VStack(alignment: .leading) {
                    Text(profile?.fullName.isEmpty == false ? profile!.fullName : "Your Name").font(.title3.bold())
                    if let email = profile?.email, !email.isEmpty {
                        Text(Masking.maskEmail(email)).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 6)
        }

        if let profile {
            Section("Contact") {
                SecureRevealRow(title: "Email", value: profile.email, masked: Masking.maskEmail)
                SecureRevealRow(title: "Phone", value: profile.phone)
                SecureRevealRow(title: "Address", value: profile.address, masked: { _ in "••••••••" })
            }
            Section("Personal") {
                SecureRevealRow(title: "Date of Birth", value: profile.dateOfBirth, masked: { _ in "••••-••-••" })
                SecureRevealRow(title: "ID / Tax Number", value: profile.nationalID)
                if !profile.employer.isEmpty { LabeledContent("Employer", value: profile.employer) }
                if let income = profile.monthlyIncome {
                    LabeledContent("Monthly income") { MoneyText(income) }
                }
            }
        } else {
            Section {
                Text("Add your details to personalise Ledgerly. Everything stays encrypted on this device and is never sent anywhere.")
                    .foregroundStyle(.secondary)
            }
        }

        Section {
            EncryptedFootnote(text: "Each field is encrypted with AES-256-GCM. The key is stored in the iOS Keychain and never leaves this device.")
        }
    }

    @ViewBuilder
    private var editForm: some View {
        Section("Contact") {
            TextField("Full name", text: $fullName).textContentType(.name)
            TextField("Email", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("Phone", text: $phone).textContentType(.telephoneNumber).keyboardType(.phonePad)
            TextField("Address", text: $address, axis: .vertical).textContentType(.fullStreetAddress).lineLimit(1...4)
        }
        Section("Personal") {
            Toggle("Date of birth", isOn: $hasDOB)
            if hasDOB {
                DatePicker("Born", selection: $dateOfBirth, in: ...Date(), displayedComponents: .date)
            }
            TextField("National ID / Emirates ID / Tax number", text: $nationalID)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.characters)
            TextField("Employer", text: $employer)
            LabeledContent("Monthly income") {
                AmountField(title: "0", amount: $monthlyIncome).multilineTextAlignment(.trailing)
            }
        }
        Section {
            EncryptedFootnote(text: "Saved encrypted. Leave any field blank to remove it.")
        }
    }

    private func load() {
        fullName = profile?.fullName ?? ""
        email = profile?.email ?? ""
        phone = profile?.phone ?? ""
        address = profile?.address ?? ""
        let dob = profile?.dateOfBirth ?? ""
        if let date = Self.dobFormatter.date(from: dob) {
            hasDOB = true
            dateOfBirth = date
        } else {
            hasDOB = false
        }
        nationalID = profile?.nationalID ?? ""
        employer = profile?.employer ?? ""
        monthlyIncome = profile?.monthlyIncome
    }

    private func save() {
        let target: UserProfile
        if let profile {
            target = profile
        } else {
            target = UserProfile()
            modelContext.insert(target)
        }
        target.fullName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        target.email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        target.phone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        target.address = address.trimmingCharacters(in: .whitespacesAndNewlines)
        target.dateOfBirth = hasDOB ? Self.dobFormatter.string(from: dateOfBirth) : ""
        target.nationalID = nationalID.trimmingCharacters(in: .whitespacesAndNewlines)
        target.employer = employer.trimmingCharacters(in: .whitespacesAndNewlines)
        target.monthlyIncome = monthlyIncome
        target.updatedAt = Date()
        try? modelContext.save()

        // Don't leave plaintext copies lingering in view state.
        fullName = ""; email = ""; phone = ""; address = ""; nationalID = ""; employer = ""; monthlyIncome = nil
        isEditing = false
    }
}
