import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  // Reliable Motivational Quotes API for Study Workspace
  static const String _quotesUrl = 'https://dummyjson.com/quotes/random';
  // Academic & Study Knowledge Fun Facts API
  static const String _academicFactsUrl = 'https://uselessfacts.jsph.pl/api/v2/facts/random';

  Future<String> fetchDailyQuote() async {
    // 1. Try Primary Motivational Quotes API
    try {
      final response = await http.get(
        Uri.parse(_quotesUrl),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final Map<String, dynamic> decoded = jsonDecode(response.body);
        final quote = decoded['quote'];
        final author = decoded['author'] ?? 'Unknown';
        if (quote != null && quote.toString().isNotEmpty) {
          return '"$quote" — $author';
        }
      }
    } on SocketException {
      rethrow; // Real offline / Airplane mode error
    } on TimeoutException {
      rethrow; // Timeout error when offline
    } catch (_) {
      // Fall through to academic facts endpoint
    }

    // 2. Fallback to Academic & Study Knowledge Fun Facts API
    try {
      final response = await http.get(
        Uri.parse(_academicFactsUrl),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final Map<String, dynamic> decoded = jsonDecode(response.body);
        final fact = decoded['text'];
        if (fact != null && fact.toString().isNotEmpty) {
          return 'Did you know? $fact';
        }
      }
    } on SocketException {
      rethrow;
    } on TimeoutException {
      rethrow;
    } catch (_) {
      // Ignore non-network errors
    }

    throw Exception('Unable to fetch quote. Please check your connection.');
  }
}
