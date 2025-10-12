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

        // Configura o AnalyticsService para encaminhar eventos ao CloudKit público
        // (AnalyticsService.cloudKitContainer e forwardToPublicCloudKit estão definidos em Analytics)
        AnalyticsService.cloudKitContainer = CKContainer(identifier: "iCloud.br.ufpe.academy.analytics")
        AnalyticsService.forwardToPublicCloudKit = true
        
        CKContainer.default().accountStatus { status, error in
            switch status {
            case .available:
                print("✅ iCloud disponível e autenticado.")
                // 🔽 Aqui você adiciona a consulta
                Task {
                    do {
                        let container = CKContainer(identifier: "iCloud.br.ufpe.academy.analytics")
                        let database = container.privateCloudDatabase
                        
                        // Query simples pra forçar criação do índice se ele não existir
                        let query = CKQuery(recordType: "CD_AnalyticsRecord", predicate: NSPredicate(value: true))
                        query.sortDescriptors = [NSSortDescriptor(key: "CD_timestamp", ascending: false)]
                        
                        let operation = CKQueryOperation(query: query)
                        operation.resultsLimit = 1
                        
                        operation.queryResultBlock = { result in
                            switch result {
                            case .success:
                                print("✅ Query index confirmed for recordName.")
                            case .failure(let error):
                                print("❌ Error confirming index: \(error.localizedDescription)")
                            }
                        }
                        database.add(operation)
                    }
                }
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
