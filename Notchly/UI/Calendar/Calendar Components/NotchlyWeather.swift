//
//  NotchlyWeather.swift
//  Notchly
//
//  Created by Mason Blumling on 2/2/25.
//

import Foundation
import SwiftUI


// MARK: - Weather Data Model
struct WeatherData {
    let temperature: Int
    let condition: String

    /// Dynamically assigns an SF Symbol based on the weather condition
    var icon: String {
        switch condition.lowercased() {
            case "sunny", "clear": return "sun.max.fill"
            case "partly cloudy": return "cloud.sun.fill"
            case "cloudy", "overcast": return "cloud.fill"
            case "rain", "showers": return "cloud.rain.fill"
            case "thunderstorm": return "cloud.bolt.rain.fill"
            case "snow": return "snowflake"
            case "fog", "mist": return "cloud.fog.fill"
            default: return "questionmark.circle.fill" // Fallback icon
        }
    }
    
    /// Formats temperature for UI display
    var formattedTemperature: String {
        "\(temperature)°"
    }
}

// MARK: - Weather Service
class WeatherService {
    static let shared = WeatherService()

    /// Fetches weather data for a given date (Mocked for now)
    func getWeather(for date: Date, completion: @escaping (WeatherData?) -> Void) {
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
            let sampleWeather = WeatherData(temperature: 72, condition: "Sunny")
            DispatchQueue.main.async {
                completion(sampleWeather)
            }
        }
    }
}

// MARK: - Weather View
struct NotchlyWeatherView: View {
    let weather: WeatherData?

    var body: some View {
        HStack(spacing: 6) {
            if let weather = weather {
                Image(systemName: weather.icon).foregroundColor(.yellow)
                Text(weather.formattedTemperature).font(.footnote).foregroundColor(NotchlyTheme.primaryText)
            } else {
                Text("—°").font(.footnote).foregroundColor(.gray)
            }
        }
    }
}
