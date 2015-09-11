angular.module("Directory.audioFiles.controllers", ['ngPlayer'])
.controller("AudioFileCtrl", ['$scope', '$timeout', '$modal', '$q', 'Player', 'Me', 'TimedText', 'AudioFile', '$http', function($scope, $timeout, $modal, $q, Player, Me, TimedText, AudioFile, $http) {
  $scope.fileUrl = $scope.audioFile.url;

  $scope.downloadLinks = [
      {
        text: 'Text Format with Timestamps',
        target: '_self',
        href: "/api/items/" + $scope.item.id + "/audio_files/" + $scope.audioFile.id + "/transcript.txt?timestamps=true"
      },
      {
        text: 'Text Format without Timestamps',
        target: '_self',
        href: "/api/items/" + $scope.item.id + "/audio_files/" + $scope.audioFile.id + "/transcript.txt?timestamps=false"
      },
      {
        text: 'SRT Format (Captions)',
        target: '_self',
        href: "/api/items/" + $scope.item.id + "/audio_files/" + $scope.audioFile.id + "/transcript.srt"
      },
      {
        text: 'XML Format (W3C Transcript)',
        target: '_self',
        href: "/api/items/" + $scope.item.id + "/audio_files/" + $scope.audioFile.id + "/transcript.xml"
      },
      {
        text: 'JSON Format',
        target: '_self',
        href: "/api/items/" + $scope.item.id + "/audio_files/" + $scope.audioFile.id + "/transcript.json"
      }
  ];
  $scope.item.formattedTitle = $scope.item.title.replace("'", "&apos;");

  $scope.embedCodesModal = $modal({template: '/assets/items/embed_codes.html', persist: true, show: false, backdrop: 'static', scope: $scope, modalClass: 'embed-codes-modal'});

  $scope.showEmbedCodesModal = function() {
    $q.when($scope.embedCodesModal).then(function(modalEl) {
      modalEl.show();
    });
  };

  $scope.play = function () {
    $scope.audioFile = new AudioFile($scope.audioFile);
    $scope.audioFile.itemId = $scope.item.id;
    $scope.audioFile.createListen();
    Player.play($scope.fileUrl, $scope.item.getTitle());
    mixpanel.track("Audio play", 
      {"Item": $scope.item.title});
  }

  $scope.player = Player;

  $scope.isPlaying = function () {
    return $scope.isLoaded() && !Player.paused();
  }

  $scope.isLoaded = function () {
    return Player.nowPlayingUrl() == $scope.fileUrl;
  }

  $scope.$on('transcriptSeek', function(event, time) {
    event.stopPropagation();
    $scope.play();
    $scope.player.seekTo(time);
  });

  Me.authenticated(function (me) {
    
    if (me.canEdit($scope.item) && $scope.item.imageFiles.slice(-1)[0]) {
      $scope.downloadLinks.unshift({
        text: 'Image File',
        target: '_self',
        href: $scope.item.imageFiles.slice(-1)[0].url.full[0]
      });
    }
    
    if (me.canEdit($scope.item)) {
      $scope.downloadLinks.unshift({
        text: 'Audio File',
        target: '_self',
        href: $scope.audioFile.original
      });
    }

    $scope.saveText = function(text) {
      var tt = new TimedText(text);
      tt.update();
    };

    $scope.orderTranscript = function () {
      $scope.audioFile = new AudioFile($scope.audioFile);
      $scope.audioFile.itemId = $scope.item.id;
      $scope.orderTranscriptModal = $modal({template: "/assets/audio_files/order_transcript.html", persist: false, show: true, backdrop: 'static', scope: $scope, modalClass: 'order-transcript-modal'});
      return;
    };

    $scope.addToAmara = function () {
      $scope.audioFile = new AudioFile($scope.audioFile);
      $scope.audioFile.itemId = $scope.item.id;
      var filename = $scope.audioFile.filename;
      return $scope.audioFile.addToAmara(me).then( function (task) {

        var msg = '"' + filename + '" added. ' +
        '<a data-dismiss="alert" data-target=":blank" ng-href="' + task.transcriptUrl + '">View</a> or ' + 
        '<a data-dismiss="alert" data-target=":blank" ng-href="' + task.editTranscriptUrl + '">edit the transcript</a> on Amara.';

        var alert = new Alert();
        alert.category = 'add_to_amara';
        alert.status   = 'Added';
        alert.progress = 1;
        alert.message  = msg;
        alert.add();
      });
    };

    $scope.showOrderTranscript = function () {
      return (new AudioFile($scope.audioFile)).canOrderTranscript(me);
    };

    $scope.showTranscriptOrdered = function () {
      return (new AudioFile($scope.audioFile)).isTranscriptOrdered();
    };

    $scope.showSendToAmara = function () {
      return (new AudioFile($scope.audioFile)).canSendToAmara(me);
    };

    $scope.showOnAmara = function () {
      return (new AudioFile($scope.audioFile)).isOnAmara();
    };

    $scope.addToAmaraTask = function () {
      return (new AudioFile($scope.audioFile)).taskForType('add_to_amara');
    };

  });
  
  $scope.callEditor = function() {
    $scope.$broadcast('CallEditor');
    mixpanel.track("Edit Transcript",{"Item": $scope.item.title});
    $scope.editTable = true;
  };

  $scope.callSave = function() {
    $scope.$broadcast('CallSave');
    $scope.editTable = false;
  };

  $scope.transcriptExpanded = false;

  $scope.expandTranscript = function () {
    $scope.transcriptExpanded = true;
  };

  $scope.collapseTranscript = function () {
    $scope.transcriptExpanded = false;
  };

  $scope.transcriptClass = function () {
    if ($scope.transcriptExpanded) {
      return "expanded";
    }
    return "collapsed";
  };

}])
.controller("OrderTranscriptFormCtrl", ['$scope', '$window', '$q', 'Me', 'AudioFile', function($scope, $window, $q, Me, AudioFile) {

  Me.authenticated(function (me) {

    $scope.length = function() {
      var mins = (new AudioFile($scope.audioFile)).durationMinutes();
      var label = "minutes";
      if (mins == 1) { label = "minute"; }
      return (mins + ' ' + label);
    }

    $scope.price = function() {
      return (new AudioFile($scope.audioFile)).transcribePrice();
    }

    $scope.submit = function () {
      $scope.audioFile.orderTranscript(me);
      $scope.clear();
      return;
    }

  });

  $scope.clear = function () {
    $scope.hideOrderTranscriptModal();
  }

  $scope.hideOrderTranscriptModal = function () {
    $q.when($scope.orderTranscriptModal).then( function (modalEl) {
      modalEl.modal('hide');
    });
  } 

}])
.controller("PersistentPlayerCtrl", ["$scope", 'Player', function ($scope, Player) {
  $scope.player = Player;
  $scope.collapsed = false;

  $scope.collapse = function () {
    $scope.collapsed = !$scope.collapsed;
  };

}]);
