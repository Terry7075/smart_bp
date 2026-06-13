class AppConstants {
  const AppConstants._();

  static const customPickupLocation = '自行輸入';
  static const customDestination = '自行輸入地點';
  static const operationsPhone = '037000000';
  static const authRedirectUrl = 'tw.mingde.transport://login-callback/';

  static const pickupLocations = <String>[
    '明德社區',
    customPickupLocation,
  ];

  static const destinations = <String>[
    '苗栗醫院',
    '大千醫院',
    '南苗市場',
    '北苗市場',
    customDestination,
  ];
}
