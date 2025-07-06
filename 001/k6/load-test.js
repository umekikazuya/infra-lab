import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('errors');

// Test configuration
export const options = {
  stages: [
    { duration: '2m', target: 20 },   // Ramp up to 20 users
    { duration: '5m', target: 20 },   // Stay at 20 users
    { duration: '2m', target: 50 },   // Ramp up to 50 users
    { duration: '5m', target: 50 },   // Stay at 50 users
    { duration: '2m', target: 100 },  // Ramp up to 100 users
    { duration: '5m', target: 100 },  // Stay at 100 users
    { duration: '2m', target: 0 },    // Ramp down to 0 users
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'],  // 95% of requests under 500ms
    http_req_failed: ['rate<0.01'],    // Error rate under 1%
    errors: ['rate<0.01'],             // Custom error rate under 1%
  },
};

// Base URL - Update this with your ALB DNS name
const BASE_URL = __ENV.BASE_URL || 'http://your-alb-dns-name.region.elb.amazonaws.com';

// Test scenarios
const scenarios = [
  {
    name: 'homepage',
    url: '/',
    weight: 40,
  },
  {
    name: 'php_info',
    url: '/info.php',
    weight: 20,
  },
  {
    name: 'database_test',
    url: '/dbtest.php',
    weight: 30,
  },
  {
    name: 'health_check',
    url: '/health.php',
    weight: 10,
  },
];

// Function to select random scenario based on weight
function selectScenario() {
  const random = Math.random() * 100;
  let cumulativeWeight = 0;
  
  for (const scenario of scenarios) {
    cumulativeWeight += scenario.weight;
    if (random <= cumulativeWeight) {
      return scenario;
    }
  }
  
  return scenarios[0]; // fallback
}

export default function () {
  const scenario = selectScenario();
  const url = BASE_URL + scenario.url;
  
  // Add some randomness to simulate real user behavior
  const params = {
    headers: {
      'User-Agent': 'k6-load-test/1.0',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'ja,en-US;q=0.7,en;q=0.3',
      'Accept-Encoding': 'gzip, deflate',
      'Connection': 'keep-alive',
    },
    timeout: '30s',
  };
  
  console.log(`Testing ${scenario.name}: ${url}`);
  
  const response = http.get(url, params);
  
  // Comprehensive checks
  const result = check(response, {
    'status is 200': (r) => r.status === 200,
    'response time < 500ms': (r) => r.timings.duration < 500,
    'response time < 1000ms': (r) => r.timings.duration < 1000,
    'response time < 2000ms': (r) => r.timings.duration < 2000,
    'response body size > 0': (r) => r.body.length > 0,
    'no server errors': (r) => !r.body.includes('Fatal error') && !r.body.includes('Warning:'),
  });
  
  // Scenario-specific checks
  if (scenario.name === 'homepage') {
    check(response, {
      'contains title': (r) => r.body.includes('LAMP Infrastructure Demo'),
      'contains system info': (r) => r.body.includes('システム情報'),
    });
  } else if (scenario.name === 'php_info') {
    check(response, {
      'contains PHP info': (r) => r.body.includes('PHP Version'),
    });
  } else if (scenario.name === 'database_test') {
    check(response, {
      'database connection works': (r) => r.body.includes('接続成功') || r.body.includes('Connection Successful'),
    });
  } else if (scenario.name === 'health_check') {
    check(response, {
      'health check returns JSON': (r) => r.headers['Content-Type'] && r.headers['Content-Type'].includes('application/json'),
      'status is healthy': (r) => r.body.includes('healthy'),
    });
  }
  
  // Track errors
  errorRate.add(!result);
  
  // Log response details for debugging
  if (response.status !== 200) {
    console.log(`❌ ${scenario.name} failed: ${response.status} - ${response.body.substring(0, 100)}...`);
  } else {
    console.log(`✅ ${scenario.name} success: ${response.timings.duration}ms`);
  }
  
  // Simulate user think time
  sleep(Math.random() * 2 + 1); // 1-3 seconds
}

// Setup function (runs once before the test)
export function setup() {
  console.log('🚀 Starting load test...');
  console.log(`Target URL: ${BASE_URL}`);
  console.log('Test scenarios:');
  scenarios.forEach(scenario => {
    console.log(`  - ${scenario.name}: ${scenario.weight}%`);
  });
  
  // Warm-up request
  const warmupResponse = http.get(BASE_URL);
  if (warmupResponse.status !== 200) {
    console.log('⚠️  Warm-up request failed. Check if the server is running.');
  } else {
    console.log('✅ Warm-up request successful');
  }
  
  return { baseUrl: BASE_URL };
}

// Teardown function (runs once after the test)
export function teardown(data) {
  console.log('🏁 Load test completed');
  console.log(`Target URL: ${data.baseUrl}`);
}

// Handle summary
export function handleSummary(data) {
  console.log('📊 Test Summary:');
  console.log(`  - Total requests: ${data.metrics.http_reqs.count}`);
  console.log(`  - Failed requests: ${data.metrics.http_req_failed.count}`);
  console.log(`  - Average response time: ${data.metrics.http_req_duration.avg.toFixed(2)}ms`);
  console.log(`  - 95th percentile: ${data.metrics.http_req_duration['p(95)'].toFixed(2)}ms`);
  console.log(`  - Error rate: ${(data.metrics.http_req_failed.rate * 100).toFixed(2)}%`);
  
  return {
    'load-test-results.json': JSON.stringify(data, null, 2),
    stdout: JSON.stringify(data, null, 2),
  };
}
