//
// Project: Firebase Auth
// File: FirebaseAuthenticatableViewModel.swift
// Copyright © 2021 Oguz Yuksel. All rights reserved.
//
// Created by Oguz Yuksel(oguz.yuuksel@gmail.com) on 27.08.2021.
//

import Firebase
import AuthenticationServices


/// `FirebaseAuthenticatableViewModel` listens Firebase Authentication status and publish current user, current login status properties while providing sign-in, sign-out, update user information abilities.
///
///# Usage:
///
///    inside `PubVMAuth.swift`
///
///        class PubVMAuth: FirebaseAuthenticatableViewModel {
///
///             MARK: Properties
///            @Published var isLoggedIn: Bool
///            @Published var user: ModelUser?
///            var authSession: ServiceAuthSession?
///            var serviceAuth: ServiceAuth
///
///             MARK: Initialization
///            init(serviceAuth: ServiceAuth = ServiceAuth(), authSession: ServiceAuthSession? = ServiceAuthSession()) {
///                self.serviceAuth = serviceAuth
///                self.authSession = authSession
///                self.user = nil
///                self.isLoggedIn = false
///            }
///
///             MARK: Functions
///            func listenAuthSession() {
///                guard authSession != nil else {
///                    print("VMFirebaseAuth.listenAuthSession(): can't listen because authSession = nil")
///                    return
///                }
///                authSession?.listenAuthentificationState()
///                authSession?.$isLoggedIn.assign(to: &$isLoggedIn)
///                authSession?.$user.map {
///                    if let validUser = $0 { return ModelUser.init(fireBaseUser: validUser) } else { return nil }
///                }
///                    .assign(to: &$user)
///            }
///
///             Customize according your project needs
///        }
///
///         MARK: - Mocked PubVMAuth
///        class PubVMAuthMock: Mockable, FirebaseAuthenticatableViewModel {
///
///             MARK: Properties
///            @Published var isLoggedIn: Bool
///            @Published var user: ModelUserMock?
///            var authSession: ServiceAuthSessionMock?
///            var serviceAuth: ServiceAuthMock
///
///             MARK: Initialization
///            init() {
///                self.serviceAuth = ServiceAuthMock()
///                self.authSession = ServiceAuthSessionMock()
///                self.user = nil
///                self.isLoggedIn = false
///            }
///
///             Customize according your project needs
///        }
///
///    inside `MainApp.swift`
///
///        import Firebase
///
///        @main
///        struct ExampleApp: App {
///            init() {
///                FirebaseApp.configure()
///            }
///            var pubVMAuth = PubVMAuth()
///
///            var body: some Scene {
///                WindowGroup {
///                    ContentView<PubVMAuth>()
///                        .environmentObject(pubVMAuth)
///                        .onAppear { pubVMAuth.listenAuthSession() }
///                    }
///                }
///            }
///        }
///
///    inside `ContentView.swift`
///
///        import AuthenticationServices
///
///        struct ContentView<TypePubVMAuth: FirebaseAuthenticatableViewModel>: View where TypePubVMAuth.TypeUser: ModelUserProtocol {
///
///             MARK: ViewModel/EnvironmentObject
///            @EnvironmentObject var pubVMAuth: TypePubVMAuth
///
///             MARK: View
///            var body: some View {
///                VStack {
///                    VStack(spacing: 4) {
///                        Text("isLoggedIn: \(pubVMAuth.isLoggedIn ? "true" : "false")")
///                        if let UID = pubVMAuth.user?.fb_uid { Text("ID: \(UID)")}
///                        if let displayName = pubVMAuth.user?.fb_name { Text("Name: \(displayName)")}
///                        if let email = pubVMAuth.user?.fb_email { Text("Email: \(email)")}
///                        if let customVar = pubVMAuth.user?.customVar { Text("customVar: \(customVar)")}
///                    }
///                    .padding()
///                    buttonSignIn
///                        .padding()
///                    buttonLogOut
///                        .padding()
///                }
///            }
///
///             MARK: ViewProperties
///            private var buttonLogOut: some View {
///                Button("LogOut", action: { pubVMAuth.signOut() })
///                    .foregroundColor(.red)
///            }
///
///            private var buttonSignIn: some View {
///                SignInWithAppleButton  { request in pubVMAuth.signInWithApple(request:  request) } onCompletion: { result in pubVMAuth.signInWithApple(result: result) }
///                    .clipShape(Capsule())
///                    .signInWithAppleButtonStyle(.white)
///                    .frame(width: 280, height: 45, alignment: .center)
///            }
///
///        }
///
///         MARK: - Preview -
///        struct ContentView_Previews: PreviewProvider {
///
///            private struct ViewWrapper: View {
///                var pubVMAuth = PubVMAuthMock()
///                var body: some View {
///                    ContentView<PubVMAuthMock>()
///                        .environmentObject(pubVMAuth)
///                }
///            }
///
///            static var previews: some View {
///                ViewWrapper()
///                    .preferredColorScheme(.dark)
///            }
///        }
protocol FirebaseAuthenticatableViewModel: ObservableObject {
    associatedtype TypeUser: FirebaseUserModellable
    associatedtype TypeAuthSession: FirebaseAuthSessionProtocol
    associatedtype TypeServiceAuth: FirebaseAuthServiceProtocol
    var isLoggedIn: Bool { get set }
    var user: TypeUser? { get set }
    var authSession: TypeAuthSession? { get set }
    var serviceAuth: TypeServiceAuth { get set }
    func listenAuthSession()
    func stopListeningAuthSession()
    func signInWithApple(request: ASAuthorizationAppleIDRequest)
    func signInWithApple(result: Result<ASAuthorization, Error>)
    func signOut()
}

extension FirebaseAuthenticatableViewModel {

//     @Published var isLoggedIn: Bool
//     @Published var user: ModelUser?
//     var authSession: ServiceAuthSession?
//     var serviceAuth: ServiceAuthProtocol
//
//      init(serviceAuth: ServiceAuthProtocol = ServiceAuth(), authSession: ServiceAuthSession? = ServiceAuthSession()) {
//          self.serviceAuth = serviceAuth
//          self.authSession = authSession
//          self.user = nil
//          self.isLoggedIn = false
//      }
//
//      func listenAuthSession() {
//          guard authSession != nil else {
//              print("VMFirebaseAuth.listenAuthSession(): can't listen because authSession = nil")
//              return
//          }
//          authSession?.listenAuthentificationState()
//          authSession?.$isLoggedIn.assign(to: &$isLoggedIn)
//          authSession?.$user.map {
//              if let validUser = $0 { return ModelUser.init(fireBaseUser: validUser) } else { return nil }
//          }
//              .assign(to: &$user)
//      }

    // I don't know in which stuation it is needed.
    func stopListeningAuthSession() {
        authSession?.stopListeningAuthentificationState()
        authSession = nil
        print("FirebaseAuthenticatableViewModel: authSession -> nil")
    }
    
    func signInWithApple(request: ASAuthorizationAppleIDRequest) {
        // requesting parameters from apple login...
        /*
         Nonces are used to make a request unique. In an authentication scheme without a nonce, a malicious client could generate a request ONCE and replay it MANY times, even if the computation is expensive. If the authentication schema requires the client to perform expensive computation for every single request, as the request is made unique by using a nonce, the replay attack is folded, as its speed just went from O(1) to O(N).
         
         The reason to have a client nonce is to prevent malicious clients do replay attacks.
         The reason to have a server nonce is to prevent a Man-in-the-Middle attacks, in case an attacker captures a valid server response, and tries to replay it to a client.
         */
        // We create nonce then send it to Apple and Firebase
        serviceAuth.createNonce() // First create nonce
        request.requestedScopes = [.email, .fullName]
        request.nonce = serviceAuth.sha256Nonce // send sha256 encoded nonce to the Apple
    }
    
    func signInWithApple(result: Result<ASAuthorization, Error>) {
        // getting error or success...
        switch result {
        case .success(let user):
            print("Successfully returned from SignInWithAppleButton")
            // login with firebase
            /*
             Authentication is the process of recognizing a user's identity. It is the mechanism of associating an incoming request with a set of identifying credentials. ... The credential often takes the form of a password, which is a secret and known only to the individual and the system.
             */
            guard let appleIDCredential = user.credential as? ASAuthorizationAppleIDCredential else {
                print("Unable to get appleIDCredential")
                return
            }
            
            // appleIDCredential doesn't contain anything except for FullName and E-Mail for user
            // so that you can't add extra field for Credentials like PremiumUser etc...
            // I don't have anything to do with firebase auth data so that I don't use completionHandler
            serviceAuth.authenticate(appleIDCredential: appleIDCredential, completionHandler: nil)
            
        case .failure(let error):
            print("Error returned from SignInWithAppleButton: \(error.localizedDescription)")
        }
    }
    
    func signOut() {
        serviceAuth.signOut()
    }
    
    func updateName(newName: String) {
        serviceAuth.updateName(newName: newName)
    }
    
    func updateEmail(newEmail: String) {
        serviceAuth.updateEmail(newEmail: newEmail)
    }
    
}

// MARK: - Mocked FirebaseAuthenticatableViewModel
/// See `FirebaseAuthenticatableViewModel` for information.
extension Mockable where Self: FirebaseAuthenticatableViewModel, Self.TypeUser: Mockable {

//     @Published var isLoggedIn: Bool
//     @Published var user: ModelUser?
//     var authSession: ServiceAuthSession?
//     var serviceAuth: ServiceAuthProtocol
//
//     init() {
//         self.serviceAuth = ServiceAuth.mockedObject()
//         self.authSession = ServiceAuthSession.MockedObject()
//         self.user = nil
//         self.isLoggedIn = false
//     }
    
    func listenAuthSession() {
        guard authSession != nil else {
            print("FirebaseAuthenticatableViewModelMock.listenAuthSession(): can't listen because authSession = nil")
            return
        }
        authSession?.listenAuthentificationState()
    }
    
    // I don't know in which stuation it is needed.
   func stopListeningAuthSession() {
        authSession?.stopListeningAuthentificationState()
        authSession = nil
        print("FirebaseAuthenticatableViewModelMock: authSession -> Nil")
    }
    
    func signInWithApple(request: ASAuthorizationAppleIDRequest) {
        #if targetEnvironment(simulator)
        // SignInWithApple doesn't return our credentials in simulator.
        // Therefore, we SignIn as soon as button clicked.
        user = TypeUser.mockedModel()
        isLoggedIn = true
        #endif
        print("FirebaseAuthenticatableViewModelMock: fire signInWithApple(request)")
    }
    
    func signInWithApple(result: Result<ASAuthorization, Error>) {
        user = TypeUser.mockedModel()
        isLoggedIn = true
        print("FirebaseAuthenticatableViewModelMock: fire signInWithApple(result)")
    }
    
    func signOut() {
        user = nil
        isLoggedIn = false
        print("FirebaseAuthenticatableViewModelMock: fire signOut()")
    }
    
    func updateName(newName: String) {
        user?.fb_name = newName
        print("FirebaseAuthenticatableViewModelMock: fire updateName(\(String(describing: user?.fb_name)))")
    }
    
    func updateEmail(newEmail: String) {
        user?.fb_email = newEmail
        print("FirebaseAuthenticatableViewModelMock: fire updateEmail(\(String(describing: user?.fb_email))) ")
    }
}
