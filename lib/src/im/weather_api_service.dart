import 'dart:convert';

import 'package:http/http.dart' as http;

class WeatherSnapshot {
  const WeatherSnapshot({
    required this.cityName,
    required this.country,
    required this.latitude,
    required this.longitude,
    required this.temperature,
    required this.windSpeed,
    required this.weatherCode,
    required this.observedAt,
  });

  final String cityName;
  final String country;
  final double latitude;
  final double longitude;
  final double temperature;
  final double windSpeed;
  final int weatherCode;
  final String observedAt;

  String get conditionLabel => weatherCodeToLabel(weatherCode);
}

class WeatherApiService {
  WeatherApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<WeatherSnapshot> fetchWeatherForCity(String cityName) async {
    final location = await _fetchLocation(cityName);
    final forecast = await _fetchCurrentWeather(
      latitude: location.latitude,
      longitude: location.longitude,
    );

    return WeatherSnapshot(
      cityName: location.name,
      country: location.country,
      latitude: location.latitude,
      longitude: location.longitude,
      temperature: forecast.temperature,
      windSpeed: forecast.windSpeed,
      weatherCode: forecast.weatherCode,
      observedAt: forecast.observedAt,
    );
  }

  Future<_WeatherLocation> _fetchLocation(String cityName) async {
    final uri = Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
      'name': cityName,
      'count': '1',
      'language': 'zh',
      'format': 'json',
    });
    final response = await _client.get(uri);

    if (response.statusCode != 200) {
      throw Exception('城市查询失败: HTTP ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final results = json['results'];
    if (results is! List || results.isEmpty) {
      throw Exception('未找到城市: $cityName');
    }

    return _WeatherLocation.fromJson(results.first as Map<String, dynamic>);
  }

  Future<_CurrentWeather> _fetchCurrentWeather({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': latitude.toStringAsFixed(4),
      'longitude': longitude.toStringAsFixed(4),
      'current_weather': 'true',
      'timezone': 'auto',
    });
    final response = await _client.get(uri);

    if (response.statusCode != 200) {
      throw Exception('天气查询失败: HTTP ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final currentWeather = json['current_weather'];
    if (currentWeather is! Map<String, dynamic>) {
      throw Exception('天气接口返回缺少 current_weather');
    }

    return _CurrentWeather.fromJson(currentWeather);
  }
}

class _WeatherLocation {
  const _WeatherLocation({
    required this.name,
    required this.country,
    required this.latitude,
    required this.longitude,
  });

  final String name;
  final String country;
  final double latitude;
  final double longitude;

  factory _WeatherLocation.fromJson(Map<String, dynamic> json) {
    return _WeatherLocation(
      name: json['name'] as String? ?? '未知城市',
      country: json['country'] as String? ?? '未知国家',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }
}

class _CurrentWeather {
  const _CurrentWeather({
    required this.temperature,
    required this.windSpeed,
    required this.weatherCode,
    required this.observedAt,
  });

  final double temperature;
  final double windSpeed;
  final int weatherCode;
  final String observedAt;

  factory _CurrentWeather.fromJson(Map<String, dynamic> json) {
    return _CurrentWeather(
      temperature: (json['temperature'] as num).toDouble(),
      windSpeed: (json['windspeed'] as num).toDouble(),
      weatherCode: (json['weathercode'] as num).toInt(),
      observedAt: json['time'] as String? ?? '未知时间',
    );
  }
}

String weatherCodeToLabel(int code) {
  return switch (code) {
    0 => '晴朗',
    1 || 2 || 3 => '多云',
    45 || 48 => '有雾',
    51 || 53 || 55 => '毛毛雨',
    56 || 57 => '冻毛毛雨',
    61 || 63 || 65 => '降雨',
    66 || 67 => '冻雨',
    71 || 73 || 75 => '降雪',
    77 => '雪粒',
    80 || 81 || 82 => '阵雨',
    85 || 86 => '阵雪',
    95 => '雷暴',
    96 || 99 => '雷暴伴冰雹',
    _ => '未知天气',
  };
}
