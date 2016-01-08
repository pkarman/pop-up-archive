angular.module('Directory.users.models', ['RailsModel'])
.factory('CreditCard', ['Model', function (Model) {
  var CreditCard = Model({url:'/api/me/credit_card', name: 'credit_card'});
  return CreditCard;
}])
.factory('Subscription', ['Model', function (Model) {
  var Subscription = Model({url:'/api/me/subscription', name: 'subscription'});
  return Subscription;
}])
.factory('User', ['Model', 'CreditCard', 'Subscription', function (Model, CreditCard, Subscription) {
  var User = Model({url:'/api/users', name: 'user'});

  User.prototype.authenticated = function (callback, errback) {
    var self = this;
    if (self.id) {
      if (callback) {
        callback(self);
      }
      if (!self.usageSummaryByMonth) {
        self.usageSummaryByMonth = self.buildUsageSummary();
      }
      return true;
    }

    if (errback) {
      errback(self);
    }
    
    return false;
  };


  User.prototype.canEdit = function (obj) {
    if (this.authenticated() && obj && obj.collectionId) {
      return (this.collectionIds.indexOf(obj.collectionId) > -1);
    } else {
      return false;
    }
  };

  User.prototype.isAdmin = function () {
    if (this.authenticated()) {
      if (this.role == 'admin' || this.role == 'owner') {
        return true;
      }
      return false;
    } else {
      return false;
    }
  };

  User.prototype.updateCreditCard = function (stripeToken) {
    var cc = new CreditCard({token: stripeToken});
    return cc.update().then(function () {
      return User.get('me');
    });
  };

  User.prototype.hasCreditCard = function () {
    return !!this.creditCard;
  };

  User.prototype.isOrgMember = function() {
    return this.role == "member";
  };

  User.prototype.mayUpload = function() {
    if (!this.overMonthlyLimit) {
      return true;
    }
    if (self.overMonthlyLimit && self.hasCreditCard() && !self.isOrgMember()) {
      return false;
    }
    return true;
  };

  User.prototype.hasCommunityPlan = function () {
    return !!(!this.plan || !this.plan.id || this.plan.id == "premium_community" || this.plan.id == "community");
  };

  User.prototype.hasPremiumTranscripts = function() {
    return this.plan.isPremium;
  };
  
  User.prototype.defaultTranscriptType = function() {
    return this.hasPremiumTranscripts() ? "premium" : "basic";
  };

  // for usage methods, if the current plan is not-community,
  // "hide" the community usage since it is free.
  User.prototype.orgUsageHours = function() {
    if (this.hasCommunityPlan()) {
      return this.organization.usage.summary.thisMonth.hours;
    }
    else {
      return (this.organization.usage.summary.thisMonth.hours - (this.organization.communityPlanUsed / 3600));
    }
  };

  User.prototype.orgUsageSecs = function() {
    if (this.hasCommunityPlan()) {
      return this.organization.usage.summary.thisMonth.secs;
    }
    else {
      return (this.organization.usage.summary.thisMonth.secs - this.organization.communityPlanUsed);
    }
  };

  User.prototype.usageSecs = function() {
    if (this.hasCommunityPlan()) {
      return this.usage.summary.thisMonth.secs;
    }
    else {
      return this.usage.summary.thisMonth.secs - this.communityPlanUsed;
    }
  };

  User.prototype.usageHours = function() {
    if (this.hasCommunityPlan()) {
      return this.usage.summary.thisMonth.hours;
    }
    else {
      return (this.usage.summary.thisMonth.hours - (this.communityPlanUsed / 3600));
    }
  };

  User.prototype.communityPlanHoursUsed = function() {
    return (this.communityPlanUsed / 3600)
  }

  User.prototype.buildUsageSummary = function() {
    var self = this;
    var groups = [];
    var curMonth = '';
    var group = [];
    // group by month, interleaving org with user if this user is in an Org
    var userInOrg = self.organization ? true : false;
    var mnthMap   = {};
    $.each(self.usage.summary.history, function(idx, msum) {
      if (msum.type.match(/usage only/)) {
        // clarify label
        msum.type = msum.type.replace(/usage only/, 'me');
      }
      else if (userInOrg) {
        return true; // skip, use org version below
      }

      // initial cap
      msum.type = msum.type.charAt(0).toUpperCase() + msum.type.slice(1);

      if (msum.period != curMonth) {
        // new group
        if (group.length > 0) {
          groups.push({period: curMonth, rows: group, charges: []});
          mnthMap[curMonth] = groups.length - 1;
        }
        group = [msum];
        curMonth = msum.period;
      }
      else {
        group.push(msum);
      }
    });
    if (group.length > 0) {
      groups.push({period: curMonth, rows: group, charges: []});
      mnthMap[curMonth] = groups.length - 1;
    }

    //console.log(mnthMap);

    if (userInOrg) {
      // do the same with org usage, interleaving
      $.each(self.organization.usage.summary.history, function(idx, msum) {
        if (self.plan.isPremium && msum.type.match(/basic/)) {
          return true; // filter out some noise
        }
        msum.type = msum.type.charAt(0).toUpperCase() + msum.type.slice(1);
        if (!msum.type.match(self.organization.name)) {
          msum.type += ' ('+self.organization.name+')';
        }
        // find the correct groups index to push to
        var gIdx = mnthMap[msum.period];
        // if could not match (not likely) then ... ??
        if (typeof gIdx == 'undefined') {
          console.log('no idx for ', msum, mnthMap);
          return true;
        }
        groups[gIdx].rows.unshift(msum); // prepend
      });
    }

    // mix in charges
    $.each(self.charges, function(idx, charge) {
      // initial cap
      charge.refType = charge.refType.charAt(0).toUpperCase() + charge.refType.slice(1);
      //console.log(charge);
      var period = charge.transactionAt.match(/^(\d\d\d\d-\d\d)/)[1];
      //console.log(period, charge);
      var gIdx = mnthMap[period];
      if (typeof gIdx == 'undefined') {
        console.log("no idx for ", period, charge);
        return true;
      }
      //console.log(gIdx, groups[gIdx]);
      groups[gIdx].charges.push(charge);
    });
    //console.log(groups);
    return groups;
  };

  User.prototype.usageDetailsByMonth = function(ym) {
    if (this.organization) {
      return this.organization.usage.transcripts[ym];
    }
    else {
      return this.usage.transcripts[ym];
    } 
  };

  User.prototype.subscribe = function (planId, offerCode) {
    var sub = new Subscription({planId: planId});
    var self = this;
    if (typeof offerCode !== 'undefined') {
      sub.offer = offerCode;
    }
    if(window.location['pathname'] === '/pricing/demo-discount') {
      sub.offer = '#DemoDiscount'
    }
    
    if(window.location['pathname'].includes('offer_code')) {
      sub.offer = 'PopUpFriend'
    } 

    return sub.update().then(function (plan) {
      return User.get('me');
    }, function(error) {
      console.log("subscription update failed: ", error);
      alert("Subscription update failed. Please contact support.");
    });
  };

  return User;
}])
