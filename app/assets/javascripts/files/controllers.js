angular.module('Directory.files.controllers', ['fileDropzone', 'Directory.alerts', 'Directory.csvImports.models', 'Directory.user', 'ngCookies', 'Directory.people.models', 'ngRoute'])
.controller('FilesCtrl', ['$window', '$cookies', '$scope', '$http', '$q', '$timeout', '$route', '$routeParams', '$modal', 'Me', 'Loader', 'CsvImport', 'Alert', 'Collection', 'Item', function FilesCtrl($window, $cookies, $scope, $http, $q, $timeout, $route, $routeParams, $modal, Me, Loader, CsvImport, Alert, Collection, Item) {

  Me.authenticated(function (me) {

    Loader.page(Collection.query(), 'Collections', $scope).then(function (data) {
    });

    // for uploads
    $scope.files = [];
    $scope.uploadModal = $modal({template: '/assets/items/form.html', persist: true, show: false, backdrop: 'static', scope: $scope, modalClass: 'item-modal'});

    // for exit survey
    // $scope.shouldShowExitSurvey = null;
    // $scope.exitSurveyModal = $modal({template: '/assets/dashboard/exit_survey.html', persist: true, show: false, backdrop: 'static', scope: $scope});

    $scope.showDetails = false;

    // check to see if there is an upload before navigating away
    $window.onbeforeunload = function(e) {
      var warn = null;
      var alerts = Alert.getAlerts();
      angular.forEach(alerts, function (alert, i) {
        if (!alert.isComplete() && alert.category == 'upload') {
          warn = "Your upload will be canceled if you leave this page. Are you sure?";
          e.returnValue = warn;
        }
      });

      // var show = $cookies.exitSurvey;

      // if (!warn && (!show || (show != 't'))) {
      //   warn = "Before you go, will you please stay long enough to answer a couple of questions?";
      //   e.returnValue = warn;
      //   $scope.shouldShowExitSurvey = $timeout(function() {
      //     $scope.showExitSurvey();
      //   }, 1000);
      // }

      return warn;
    };

    $window.unload = function(e) {
      $timeout.cancel($scope.shouldShowExitSurvey);
    };

    // $scope.showExitSurvey = function () {
    //   // Retrieving a cookie
    //   var show = $cookies.exitSurvey;
    // 
    //   if(show && show == 't') {
    //     console.log('Already seen the survey');
    //   } else {
    // 
    //     $q.when($scope.exitSurveyModal).then( function (modalEl) {
    //       modalEl.modal('show');
    //     });
    //     $cookies.exitSurvey = 't';
    //   }
    // };

    $scope.uploadFile = function () {
      $scope.initializeItem(true);
      $scope.$emit('filesAdded', []);
    };

    // Sets the default collection for uploads to the most recent collection
    $scope.mostRecent = function () {
      var cols = $scope.collections;
      var mostRecent = cols[0];
      for (var i=1; i<cols.length; i++) {
        if ((cols[i].id > mostRecent.id)){
          mostRecent = cols[i];
        }
      }
      return mostRecent.id;
    };

    $scope.uploadItemToCollection = function(id) {
      $scope.selectedCollection = id;
      $scope.uploadFile();
    };

    $scope.uploadCSV = function (file) {
      var alert = new Alert();
      alert.category = 'upload';
      alert.status = "Uploading";
      alert.progress = 1;
      alert.message = file.name;
      alert.add();

      var fData = new FormData();
      fData.append('csv_import[file]', file);

      $http({
        method: 'POST',
        url: '/api/csv_imports',
        data: fData,
        headers: { "Content-Type": undefined },
        transformRequest: angular.identity
      }).success(function(data, status, headers, config) {
        var csvImport = new CsvImport({id:data.id});
        alert.progress = 25;
        alert.status = "Waiting";
        alert.startSync(csvImport.alertSync());
      });
    };


    $scope.initializeItem = function(force) {
      //console.log('initializeItem', $scope.item, $scope);

      if ($route.current.controller == 'ItemCtrl' && 
          $route.current.locals.$scope.item &&
          $route.current.locals.$scope.item.id > 0)
      {
        $scope.item = $route.current.locals.$scope.item;
        //console.log('initializeItem set to', $route.current.locals.$scope.item.id, $route.current.locals.$scope.item);
      } else {

        // start a new item if there is not one already in scope
        if(force || !$scope.item) {
          console.log('initializeItem new item', $scope.item);
          var collectionId = parseInt($routeParams.collectionId, 10) || $scope.selectedCollection || $scope.mostRecent();
          var newItem = new Item({collectionId:collectionId, title:'', files:[], images:[angular.element('#image').value]});
          $scope.item = newItem;
          //console.log('initializeItem make new', newItem);
        }
      }

      //console.log('initializeItem end', $scope.item);
      return $scope.item;
    };

    $scope.handleAudioFilesAdded = function (newFiles) {
      //console.log('handleAudioFilesAdded', newFiles, $scope.item, $scope);

      var newFiles = newFiles || [];
      var newImages = newImages || [];
      $scope.initializeItem();

      //console.log('handleAudioFilesAdded - add files', newFiles, $scope.item, $scope);

      // set initial item transcript type based on user default
      $scope.item.transcriptType = $scope.currentUser.defaultTranscriptType();

      // add files to the item
      if (!$scope.item.files) {
        $scope.item.files = [];
      }

      if (!$scope.item.images) {
        $scope.item.images = [];
      }

      angular.forEach(newFiles, function (file) {
        $scope.item.files.push(file);
      });

      angular.forEach(newImages, function (image){
        $scope.item.images.push(image);
      });

      // default title to first file if not already set
      if (newFiles.length >= 1 && (!$scope.item.title || $scope.item.title == "")) {
        $scope.item.title = newFiles[0].name;
      }

      // all set, now show that modal!
      $q.when($scope.uploadModal).then( function (modalEl) {
        modalEl.show();
      });

      //console.log('handleAudioFilesAdded - done', $scope.item, $scope);

    };

    $scope.uploadAudioFiles = function (item, newFiles) {
      //console.log('$scope.uploadAudioFiles', item, newFiles);
      angular.forEach(newFiles, function (file) {
        $scope.uploadAudioFile(item, file);
      });
    };

    $scope.uploadImageFiles = function (item, newImageFiles) {
      // console.log('$scope.uploadAudioFiles', item, newFiles);
      angular.forEach(newImageFiles, function (file) {
        $scope.uploadImageFile(item, file);
      });
    };



    $scope.uploadAudioFile = function (item, file) {
      var item = item;
      var alert = new Alert();
      alert.category = 'upload';
      alert.status   = 'Uploading';
      alert.progress = 1;
      alert.message  = file.name;
      alert.add();
      alert.path = item.link();

      file.alert = alert;

      var audioFile = item.addAudioFile(file,
      {
        onComplete: function () {
          var msg = '"' + file.name + '" upload completed.';
          msg    += '<a ng-href="' + item.link() + '" href="' + item.link() + '"> View and edit the item!</a>';
          mixpanel.track(
            "Audio Upload Complete", {
              "Collection": item.collectionId + ' ' +item.collectionTitle,
              "Storage": item.storage,
              "User": $scope.currentUser.name + ' ' + $scope.currentUser.email
            }
          );

          $scope.addMessage({
            'type': 'success',
            'title': 'Congratulations!',
            'content': msg
          });

          alert.progress = 100;
          alert.status   = "Complete";

          // let search results know that there is a new item
          $timeout(function () { $scope.$broadcast('datasetChanged')}, 750);
        },
        onError: function () {
          console.log('fileUploaded: addAudioFile: error', item);
          $scope.addMessage({
            'type': 'error',
            'title': 'Oops...',
            'content': '"' + file.name + '" upload failed. Hmmm... try again?'
          });

          alert.progress = 100;
          alert.status   = "Error";
          mixpanel.track(
            "Audio Upload Failed", {
              "User": $scope.currentUser.name + ' ' + $scope.currentUser.email}
          );
        },
        onProgress: function (progress) {
          console.log('uploadAudioFiles: onProgress', progress);
          alert.progress = progress;
        }
      });
    }

    $scope.uploadImageFile = function (item, file) {
      var item = item;
      var alert = new Alert();
      alert.category = 'upload';
      alert.status   = 'Uploading';
      alert.progress = 1;
      alert.message  = file.name;
      alert.add();
      alert.path = item.link();

      file.alert = alert;

      var imageFile = item.addImageFile(file,
      {
        onComplete: function () {
          // console.log($scope.item.id, $scope.currentUser.uploadsCollectionId);
          var msg = '"' + file.name + '" upload completed.';
          msg    += '<a ng-href="' + item.link() + '" href="' + item.link() + '"> View and edit the item!</a>';

          $scope.addMessage({
            'type': 'success',
            'title': 'Congratulations!',
            'content': msg
          });

          alert.progress = 100;
          alert.status   = "Complete";

          // let search results know that there is a new item
          $timeout(function () { $scope.$broadcast('datasetChanged')}, 750);
          $route.reload();
        },
        onError: function () {
          console.log('fileUploaded: addAudioFile: error', item);
          $scope.addMessage({
            'type': 'error',
            'title': 'Oops...',
            'content': '"' + file.name + '" upload failed. Hmmm... try again?'
          });

          alert.progress = 100;
          alert.status   = "Error";
        },
        onProgress: function (progress) {
          console.log('uploadAudioFiles: onProgress', progress);
          alert.progress = progress;
        }
      });
    }    

    $scope.hideUploadModal = function() {
      $q.when($scope.uploadModal).then( function (modalEl) {
        modalEl.modal('hide');
      });
    } 


    $scope.$on("filesAdded", function (e, newFiles) {
      console.log('on filesAdded', newFiles);
      $scope.handleAudioFilesAdded(newFiles);
    });

    $scope.$watch('files', function(files) {

      //new files!
      var newFiles = [];

      var newFile;
      while (newFile = files.pop()) {
        if (newFile.name.match(/csv$/i)) {
          $scope.uploadCSV(newFile);
        } else {
          newFiles.push(newFile);
        }
      }

      if (newFiles.length > 0) {
        console.log('new files added', newFiles);
        $scope.$broadcast('filesAdded', newFiles);
      }

    });
  });
}]);
