import SwiftUI
import PhotosUI
import CoreLocation

@MainActor
class AeroFindrViewModel: ObservableObject {
    @Published var flightInfo: FlightInfo?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let aviationService = AviationStackService()
    private let metadataService = ImageMetadataService()
    
    func processImage(_ image: UIImage) {
        isLoading = true
        errorMessage = nil
        flightInfo = nil
        
        Task {
            do {
                guard let metadata = metadataService.extractMetadata(from: image) else {
                    throw ProcessingError.noMetadata
                }
                
                guard let location = metadata.location else {
                    throw ProcessingError.noLocation
                }
                
                let timestamp = metadata.timestamp ?? Date()
                
                try await searchFlights(location: location, timestamp: timestamp)
                
            } catch {
                errorMessage = error.localizedDescription
            }
            
            isLoading = false
        }
    }
    
    func processSelectedPhoto(_ photoItem: PhotosPickerItem) {
        isLoading = true
        errorMessage = nil
        flightInfo = nil
        
        Task {
            do {
                guard let imageData = try await photoItem.loadTransferable(type: Data.self) else {
                    throw ProcessingError.failedToLoadImage
                }
                
                guard let metadata = metadataService.extractMetadata(from: imageData) else {
                    throw ProcessingError.noMetadata
                }
                
                guard let location = metadata.location else {
                    throw ProcessingError.noLocation
                }
                
                let timestamp = metadata.timestamp ?? Date()
                
                try await searchFlights(location: location, timestamp: timestamp)
                
            } catch {
                errorMessage = error.localizedDescription
            }
            
            isLoading = false
        }
    }
    
    private func searchFlights(location: CLLocationCoordinate2D, timestamp: Date) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            aviationService.searchFlights(near: location, timestamp: timestamp) { result in
                switch result {
                case .success(let flights):
                    if let firstFlight = flights.first {
                        self.flightInfo = firstFlight
                    } else {
                        self.errorMessage = "No flights found in this area at this time"
                    }
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

enum ProcessingError: LocalizedError {
    case noMetadata
    case noLocation
    case failedToLoadImage
    
    var errorDescription: String? {
        switch self {
        case .noMetadata:
            return "Could not extract metadata from image"
        case .noLocation:
            return "No GPS location found in image. Make sure location services are enabled when taking photos."
        case .failedToLoadImage:
            return "Failed to load selected image"
        }
    }
}