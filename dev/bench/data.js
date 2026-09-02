window.BENCHMARK_DATA = {
  "lastUpdate": 1788366056398,
  "repoUrl": "https://github.com/alex-tomilov/dry-validation-rust",
  "entries": {
    "Schema throughput p95 latency": [
      {
        "commit": {
          "author": {
            "email": "atomilov25@gmail.com",
            "name": "Alexey Tomilov",
            "username": "alex-tomilov"
          },
          "committer": {
            "email": "atomilov25@gmail.com",
            "name": "Alexey Tomilov",
            "username": "alex-tomilov"
          },
          "distinct": true,
          "id": "56ecbf945440adf8d05565054b5b221ce08d5012",
          "message": "fix(docs): route yard reference through mdbook chapter",
          "timestamp": "2026-09-02T21:18:08+05:00",
          "tree_id": "9841fce2ef3d4d915192ac7dcf651caca704847e",
          "url": "https://github.com/alex-tomilov/dry-validation-rust/commit/56ecbf945440adf8d05565054b5b221ce08d5012"
        },
        "date": 1788366055351,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "dry-validation-rust small_form p95 latency",
            "value": 15.519999976731924,
            "unit": "microseconds",
            "extra": "throughput_per_second: 80693.5982734383\nruby_allocated_objects_per_call: 70.001\npeak_rss_kb: 33396\nrss_after_kb: 33396\npss_after_kb: 31012\nuss_after_kb: 30820"
          },
          {
            "name": "dry-validation-rust medium_form p95 latency",
            "value": 319.72300001825715,
            "unit": "microseconds",
            "extra": "throughput_per_second: 11467.658556136585\nruby_allocated_objects_per_call: 405.6001\npeak_rss_kb: 34356\nrss_after_kb: 34356\npss_after_kb: 31908\nuss_after_kb: 31716"
          },
          {
            "name": "dry-validation-rust large_form p95 latency",
            "value": 1125.3019999912794,
            "unit": "microseconds",
            "extra": "throughput_per_second: 1693.7432720251027\nruby_allocated_objects_per_call: 2581.5001\npeak_rss_kb: 34364\nrss_after_kb: 34364\npss_after_kb: 31916\nuss_after_kb: 31724"
          },
          {
            "name": "dry-validation-rust nested_object p95 latency",
            "value": 23.17299998821909,
            "unit": "microseconds",
            "extra": "throughput_per_second: 49031.903073534624\nruby_allocated_objects_per_call: 128.0001\npeak_rss_kb: 34492\nrss_after_kb: 34492\npss_after_kb: 32048\nuss_after_kb: 31856"
          },
          {
            "name": "dry-validation-rust array_of_objects p95 latency",
            "value": 400.1000000357635,
            "unit": "microseconds",
            "extra": "throughput_per_second: 3512.532118874663\nruby_allocated_objects_per_call: 1651.2001\npeak_rss_kb: 34496\nrss_after_kb: 34496\npss_after_kb: 32043\nuss_after_kb: 31856"
          },
          {
            "name": "dry-validation-rust all_invalid p95 latency",
            "value": 409.8729999668649,
            "unit": "microseconds",
            "extra": "throughput_per_second: 4451.705342054321\nruby_allocated_objects_per_call: 893.0001\npeak_rss_kb: 34560\nrss_after_kb: 34560\npss_after_kb: 32106\nuss_after_kb: 31920"
          },
          {
            "name": "dry-validation-rust sparse_optional p95 latency",
            "value": 52.939999989121134,
            "unit": "microseconds",
            "extra": "throughput_per_second: 26092.548222889684\nruby_allocated_objects_per_call: 230.0001\npeak_rss_kb: 34560\nrss_after_kb: 34560\npss_after_kb: 32110\nuss_after_kb: 31924"
          },
          {
            "name": "dry-validation-rust mixed_types p95 latency",
            "value": 45.02499996306142,
            "unit": "microseconds",
            "extra": "throughput_per_second: 31420.15901314958\nruby_allocated_objects_per_call: 190.0001\npeak_rss_kb: 34564\nrss_after_kb: 34564\npss_after_kb: 32110\nuss_after_kb: 31924"
          },
          {
            "name": "dry-validation-rust array_of_primitives p95 latency",
            "value": 75.69299998522183,
            "unit": "microseconds",
            "extra": "throughput_per_second: 15050.643526612048\nruby_allocated_objects_per_call: 40.0001\npeak_rss_kb: 34896\nrss_after_kb: 34896\npss_after_kb: 32442\nuss_after_kb: 32256"
          },
          {
            "name": "dry-validation-rust wide_nested_object p95 latency",
            "value": 295.3279999928782,
            "unit": "microseconds",
            "extra": "throughput_per_second: 6860.036855026797\nruby_allocated_objects_per_call: 920.0001\npeak_rss_kb: 35260\nrss_after_kb: 35260\npss_after_kb: 32806\nuss_after_kb: 32620"
          },
          {
            "name": "dry-validation-rust ruby_rules p95 latency",
            "value": 76.61500001177046,
            "unit": "microseconds",
            "extra": "throughput_per_second: 15665.553491756737\nruby_allocated_objects_per_call: 253.8001\npeak_rss_kb: 35392\nrss_after_kb: 35392\npss_after_kb: 32938\nuss_after_kb: 32752"
          },
          {
            "name": "dry-validation small_form p95 latency",
            "value": 38.69300002179443,
            "unit": "microseconds",
            "extra": "throughput_per_second: 31653.76283614697\nruby_allocated_objects_per_call: 49.001\npeak_rss_kb: 38280\nrss_after_kb: 38280\npss_after_kb: 33489\nuss_after_kb: 30984"
          },
          {
            "name": "dry-validation medium_form p95 latency",
            "value": 1869.4849999860708,
            "unit": "microseconds",
            "extra": "throughput_per_second: 2288.257417349769\nruby_allocated_objects_per_call: 1116.8001\npeak_rss_kb: 38536\nrss_after_kb: 38536\npss_after_kb: 33749\nuss_after_kb: 31240"
          },
          {
            "name": "dry-validation large_form p95 latency",
            "value": 7169.756999985566,
            "unit": "microseconds",
            "extra": "throughput_per_second: 272.893731882693\nruby_allocated_objects_per_call: 10286.0001\npeak_rss_kb: 38936\nrss_after_kb: 38936\npss_after_kb: 34149\nuss_after_kb: 31640"
          },
          {
            "name": "dry-validation nested_object p95 latency",
            "value": 74.77100001551662,
            "unit": "microseconds",
            "extra": "throughput_per_second: 16242.432283314683\nruby_allocated_objects_per_call: 113.0001\npeak_rss_kb: 39076\nrss_after_kb: 39076\npss_after_kb: 34289\nuss_after_kb: 31780"
          },
          {
            "name": "dry-validation array_of_objects p95 latency",
            "value": 1777.2639999975581,
            "unit": "microseconds",
            "extra": "throughput_per_second: 636.6777675308568\nruby_allocated_objects_per_call: 1713.6001\npeak_rss_kb: 39500\nrss_after_kb: 39196\npss_after_kb: 34409\nuss_after_kb: 31900"
          },
          {
            "name": "dry-validation all_invalid p95 latency",
            "value": 1646.593000032226,
            "unit": "microseconds",
            "extra": "throughput_per_second: 675.2829941431143\nruby_allocated_objects_per_call: 4063.0001\npeak_rss_kb: 39500\nrss_after_kb: 39272\npss_after_kb: 34485\nuss_after_kb: 31976"
          },
          {
            "name": "dry-validation sparse_optional p95 latency",
            "value": 233.2600000158891,
            "unit": "microseconds",
            "extra": "throughput_per_second: 6210.562774996332\nruby_allocated_objects_per_call: 379.0001\npeak_rss_kb: 39508\nrss_after_kb: 39508\npss_after_kb: 34657\nuss_after_kb: 32148"
          },
          {
            "name": "dry-validation mixed_types p95 latency",
            "value": 97.50400005259507,
            "unit": "microseconds",
            "extra": "throughput_per_second: 12123.717248580388\nruby_allocated_objects_per_call: 109.0001\npeak_rss_kb: 39752\nrss_after_kb: 39752\npss_after_kb: 34901\nuss_after_kb: 32392"
          },
          {
            "name": "dry-validation array_of_primitives p95 latency",
            "value": 402.81899998717563,
            "unit": "microseconds",
            "extra": "throughput_per_second: 2570.0953186208567\nruby_allocated_objects_per_call: 39.0001\npeak_rss_kb: 42096\nrss_after_kb: 42096\npss_after_kb: 37245\nuss_after_kb: 34736"
          },
          {
            "name": "dry-validation wide_nested_object p95 latency",
            "value": 372.34100000205217,
            "unit": "microseconds",
            "extra": "throughput_per_second: 3123.619858825465\nruby_allocated_objects_per_call: 329.0001\npeak_rss_kb: 43612\nrss_after_kb: 43612\npss_after_kb: 38761\nuss_after_kb: 36252"
          },
          {
            "name": "dry-validation ruby_rules p95 latency",
            "value": 208.1210000142164,
            "unit": "microseconds",
            "extra": "throughput_per_second: 7216.617546458552\nruby_allocated_objects_per_call: 385.6001\npeak_rss_kb: 43620\nrss_after_kb: 43620\npss_after_kb: 38769\nuss_after_kb: 36260"
          }
        ]
      }
    ]
  }
}