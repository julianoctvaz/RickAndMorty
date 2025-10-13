//
//  RickAndMortyApp.swift
//  RickAndMorty
//
//  Created by Jamerson Macedo on 16/08/24.
//

import SwiftUI
import SwiftData
import CloudKit
import UserNotifications

@main
struct RickAndMortyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appdelegate
    
    private let modelContainer: ModelContainer = {
        do {
            return try SwiftDataStack.makeContainer()
        } catch {
            fatalError("❌ Failed to init ModelContainer: \(error)")
        }
    }()

    init(){
        requestNotificationPermission() // solicita a permissão

        AnalyticsService.cloudKitContainer = CKContainer(identifier: "iCloud.br.ufpe.academy.analytics")
        
        CKContainer.default().accountStatus { status, error in
            switch status {
            case .available:
                print("✅ iCloud disponível e autenticado.")
            case .noAccount:
                print("⚠️ Nenhuma conta iCloud configurada.")
            case .restricted:
                print("🚫 Acesso restrito ao iCloud.")
            case .couldNotDetermine:
                print("❓ Não foi possível determinar o status do iCloud.")
            case .temporarilyUnavailable:
                print("⏳ iCloud temporariamente indisponível.")
            @unknown default:
                print("❗️Status de iCloud desconhecido.")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            RickAndMortyView(viewmodel: RickAndMortyViewModel(service: RickAndMortyService()))
                .modelContainer(modelContainer)
        }
    }

    private func requestNotificationPermission(){
        // .alert e os demais são os tipos de permissoes
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert,.badge,.sound]){ granted, error in
            if let error = error {
                print(error.localizedDescription)
            } else {
                print("Notification permission granted: \(granted)")
            }
        }
    }
}

class AppDelegate : NSObject,UIApplicationDelegate,UNUserNotificationCenterDelegate{
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner,.sound])
    }
}
