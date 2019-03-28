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
      $scope.tagCloud = [];
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
          buildTagCloud($scope.db.Apps);
          $scope.updateSearchResult();
          updateSelectedApp();
          $scope.dbLoadError = false;
        }, function () {
          $scope.dbLoadError = true;
        });

      function normalizeString(s) {
        return _.trim(_.toLower(s), ' "');
      }

      function splitKeywords(s) {
        var matches = s.match(/"[^"]+"|[^"\s]+/g);
        return _.map(matches, normalizeString);
      }

      function checkKeyword(app, keyword) {
        if (_.includes(normalizeString(app.Label), keyword)) {
          return true;
        }
        if (_.includes(normalizeString(app.Category), keyword)) {
          return true;
        }
        if (_.includes(normalizeString(app.ExeName), keyword)) {
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

      function wordWeight(stepSize) {
        return function (size) {
          return 9 + Math.pow(1 + size, 0.9) * stepSize * 4;
        };
      }

      function wordColor(maxSize) {
        var colors = [
          '#424242',
          '#86ae1e',
          '#86ae1e',
          '#1ba1e2',
          '#1ba1e2',
          '#267d41',
          '#267d41',
          '#267d41',
          '#0072c6',
          '#0072c6',
          '#0072c6',
          '#ffc400'
        ];
        return function wordColor(word, size) {
          return _.sample(colors);
        };
      }

      function wordClick(p, d, e) {
        var word = p[0];
        $scope.search = word.indexOf(' ') >= 0 ? '"' + word + '"' : word;
        $scope.$apply();
      }

      function wordHover(p, d, e) {
        var wordcloudE = document.getElementById('wordcloud');
        wordcloudE.style.cursor = p ? 'pointer' : 'default';
      }

      function buildTagCloud(apps) {
        $scope.tagCloud = _.toPairs(_.countBy(_.flatten(_.map(apps, 'Tags'))));
        var maxCount = _.max(_.map($scope.tagCloud, function (e) { return e[1]; }));
        var wordcloudE = document.getElementById('wordcloud');
        wordcloudE.height = wordcloudE.width = Math.min(
          (window.innerWidth || 0) * 0.75,
          (window.innerHeight || 0) * 0.5);
        if (wordcloudE && WordCloud.isSupported) {
          var stepSize = wordcloudE.getBoundingClientRect().width / 1024.0;
          WordCloud(wordcloudE, {
            list: $scope.tagCloud,
            gridSize: Math.round(16 * stepSize),
            weightFactor: wordWeight(stepSize),
            fontFamily: "Segoe UI, Arial, Helvetica, sans-serif",
            fontWeight: 500,
            color: wordColor(maxCount),
            click: wordClick,
            hover: wordHover,
            rotateRatio: 0.3,
            rotationSteps: 2,
            ellipticity: 1,
            shape: 'square',
            clearCanvas: true,
            backgroundColor: '#fff'
          });
        }
      }

      $scope.search = '';
      $scope.updateSearchResult = function () {
        if (!$scope.search) {
          $scope.keywords = [];
          $scope.selectedApps = [];
        } else {
          var keywords = splitKeywords($scope.search);
          $scope.keywords = keywords;
          $scope.selectedApps = _.chain($scope.apps)
            .values()
            .filter(function (app) { return checkKeywords(app, keywords); })
            .sortBy('Label')
            .value();
        }
      };
      $scope.$watch('search', $scope.updateSearchResult);

      $scope.searchFor = function (text) {
        if (_.includes(text, ' ')) text = '"' + text + '"';
        $scope.search = text;
        $scope.hideAppDetails();
      };

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
