//
//  FAAService.swift
//  WarDragon
//
//  Created by Luke on 4/25/25.
//

import Foundation
import Combine

class FAAService: ObservableObject {
    static let shared = FAAService()
    
    @Published var isFetching = false
    @Published var error: String?
    
    private let faaBaseURL = "https://uasdoc.faa.gov"
    private let faaAPIEndpoint = "/api/v1/serialNumbers"
    
    // Create a session with custom headers
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:137.0) Gecko/20100101 Firefox/137.0",
            "Accept": "application/json, text/plain, */*",
            "Accept-Language": "en-US,en;q=0.5",
            "Referer": "https://uasdoc.faa.gov/listdocs",
            "client": "external"
        ]
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config)
    }()
    
    // Refresh the FAA cookie before making requests
    private func refreshCookie() async throws {
        let homepageURL = URL(string: "\(faaBaseURL)/listdocs")!
        do {
            let (_, response) = try await session.data(from: homepageURL)
            if let httpResponse = response as? HTTPURLResponse {
                print("FAA homepage response code: \(httpResponse.statusCode)")
            }
        } catch {
            print("Error refreshing FAA cookie: \(error)")
            throw error
        }
    }
    
    func queryFAAData(mac: String, remoteId: String) async -> [String: Any]? {
        
        guard !remoteId.isEmpty else {
            DispatchQueue.main.async {
                self.error = "Remote ID is empty"
            }
            return nil
        }
        
        // Debug print to see what's being passed
        print("FAA Query - MAC: \(mac), remoteId: \(remoteId)")
        
        // Check cache first
        if let cachedData = checkCache(mac: mac, remoteId: remoteId) {
            print("FAA Cache Hit")
            return cachedData
        }
        
        DispatchQueue.main.async {
            self.isFetching = true
            self.error = nil
        }
        
        do {
            // Refresh cookie first
            try await refreshCookie()
            
            // Build the FAA query URL with parameters
            var components = URLComponents(string: "\(faaBaseURL)\(faaAPIEndpoint)")!
            components.queryItems = [
                URLQueryItem(name: "itemsPerPage", value: "8"),
                URLQueryItem(name: "pageIndex", value: "0"),
                URLQueryItem(name: "orderBy[0]", value: "updatedAt"),
                URLQueryItem(name: "orderBy[1]", value: "DESC"),
                URLQueryItem(name: "findBy", value: "serialNumber"),
                URLQueryItem(name: "serialNumber", value: remoteId)
            ]
            
            guard let url = components.url else {
                throw NSError(domain: "FAAService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
            }
            
            print("FAA Request URL: \(url.absoluteString)")
            
            // Make the request
            let (data, response) = try await session.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("FAA Response status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    throw NSError(domain: "FAAService",
                                  code: httpResponse.statusCode,
                                  userInfo: [NSLocalizedDescriptionKey: "FAA HTTP error: \(httpResponse.statusCode)"])
                }
            }
            
            // Print raw response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("FAA Response: \(responseString)")
            }
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                // Cache the result
                cacheResult(mac: mac, remoteId: remoteId, data: json)
                
                DispatchQueue.main.async {
                    self.isFetching = false
                }
                
                return json
            } else {
                throw NSError(domain: "FAAService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response"])
            }
            
        } catch {
            DispatchQueue.main.async {
                self.isFetching = false
                self.error = error.localizedDescription
            }
            print("Error querying FAA API: \(error)")
            return nil
        }
    }
    
    // Cache functions
    private func cacheResult(mac: String, remoteId: String, data: [String: Any]) {
        let key = "\(mac)_\(remoteId)"
        UserDefaults.standard.set(data, forKey: "faa_cache_\(key)")
    }
    
    private func checkCache(mac: String, remoteId: String) -> [String: Any]? {
        let key = "\(mac)_\(remoteId)"
        return UserDefaults.standard.dictionary(forKey: "faa_cache_\(key)")
    }
}
