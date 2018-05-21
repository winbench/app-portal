angular.module('benchApps', [])
  .directive('markdown', function () {
    var converter = new showdown.Converter();
    return {
      restrict: 'A',
      link: function (scope, element, attrs) {
        scope.$watch(attrs.markdown, function (value) {
          element.html(converter.makeHtml(value));
        });
      }
    };
  })
  .controller('AppSearchController', ['$scope', '$http', '$location',
    function ($scope, $http, $location) {

      $scope.db = {};
      $scope.appLibs = {};
      $scope.apps = {};
      $scope.selectedApps = [];
      $scope.app = null;
      $scope.dbLoadError = false;

      $scope.notEmpty = function (v) { return !_.isEmpty(v); };

      $http.get('bench-apps-db.json')
        .then(function (response) {
          $scope.db = response.data;
          $scope.db.LastUpdateStr = moment($scope.db.LastUpdate).calendar();
          $scope.appLibs = _.keyBy($scope.db.AppLibraries, function (appLib) {
            return appLib.ID;
          });
          $scope.apps = _.keyBy($scope.db.Apps, function (app) {
            return app.ID;
          });
          $scope.updateSearchResult();
          updateSelectedApp();
          $scope.dbLoadError = false;
        }, function () {
          $scope.dbLoadError = true;
        });

      function normalizeString(s) {
        return _.lowerCase(s);
      }

      function splitKeywords(s) {
        return s.split(/\s+/);
      }

      function checkKeyword(app, keyword) {
        if (_.includes(normalizeString(app.Label), keyword)) {
          return true;
        }
        if (_.includes(normalizeString(app.Category), keyword)) {
          return true;
        }
        if (app.Tags && app.Tags.length > 0 &&
            _.some(app.Tags, function (t) { return normalizeString(t) == keyword; })) {
          return true;
        }
        return false;
      }

      function checkKeywords(app, keywords) {
        return _.every(keywords, function (k) { return checkKeyword(app, k); });
      }

      $scope.search = '';
      $scope.updateSearchResult = function () {
        if (!$scope.search) {
          $scope.selectedApps = [];
        } else {
          var search = normalizeString($scope.search);
          var keywords = splitKeywords(search);
          $scope.selectedApps = _.chain($scope.apps)
            .values()
            .filter(function (app) { return checkKeywords(app, keywords); })
            .sortBy('Label')
            .value();
        }
      };
      $scope.$watch('search', $scope.updateSearchResult);

      function updateSelectedApp() {
        var appId = $location.hash();
        $scope.app = $scope.apps[appId];
      }
      $scope.$on('$locationChangeSuccess', updateSelectedApp);

      $scope.showAppDetails = function (app) {
        $location.hash(app.ID);
      };
      $scope.hideAppDetails = function () {
        $location.hash('');
      };
    }
  ]);