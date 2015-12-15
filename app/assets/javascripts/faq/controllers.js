angular.module('Directory.faq.controllers', ['Directory.loader', 'Directory.user'])
.controller('FAQController', ['$scope', 'Me', '$location', '$anchorScroll', function ItemsCtrl($scope, Me, $location, $anchorScroll) {

	$scope.scrollTo = function(link) {
		console.log('clicked');
		console.log(link);
    	$location.hash(link);
     	$anchorScroll();
	}

	$scope.faq = [
		{
			title: "Getting Started",
			link: "get_started",
			questions: [

				{
					question: "What is Pop Up Archive? Who is it for?",
					answer: "Pop Up Archive is a platform of tools for organizing and searching digital spoken word. We process sound for a wide range of customers, from large archives and universities to media companies, radio stations, and podcast networks. Drag and drop any audio file (or let us ingest your RSS, SoundCloud, or iTunes feed), and within minutes receive automatically generated transcripts and tags. Pop Up Archive transcripts help producers log and search their raw tape, repurpose audio stories into text posts faster, add text content to stations’ websites, and ensure that audio and video get indexed by Google for the most innovative digital media properties.",
				},
				{
					question: "How does Pop Up Archive compare to human transcription?",
					answer: "The short answer is that automatic transcription is usually less accurate than human transcription. But getting verbatim human transcripts is expensive, slow and labor-intensive — and search engines don’t need perfect transcripts. There are ways to be smart about interpreting messy output, and to use that data to extract relevant keywords and metadata. It’s like magic: When you pair text content with timestamps, audio becomes browsable. Harnessed the right way, speech-to-text software means effortless access to crucial keywords and moments hidden deep within hours of content.",
				},
			]
		},
		{
			title: "Transcripts and Audio Quality",
			link: "transcripts",
			questions: [
				{
					question: "What are premium transcripts?", 
					answer: "Premium transcripts use automatic speech recognition software to create time-stamped text and keyword tags from audio. Other features include speaker differentiation (in beta), punctuation, and capitalization. The software is trained on a large corpus of broadcast and oral history voices, and is updated regularly for current names and vocabulary. Transcripts are generated in real time (e.g. a hour audio file will be processed in approximately one hour). Accuracy varies depending on factors like audio quality and speaker dialect, so often the best way to guage accuracy for your audio is to try it out for yourself."
				},
				{
					question: "What languages and accents does Pop Up Archive support?",
					answer: "Pop Up Archive's speech-to-text software currently only supports English language audio. We hope to expand to Spanish language and other major languages in 2015. Because our transcription software is trained on voices from mass media, both Premium and Basic software performs best for dialects heavily represented in American and British broadcast media. That said, feel free to try us out with any accents you've got, and let us know how it goes!",
				},
				{
					question: "Why do the automatic transcripts and tags have errors?",
					answer: "Automatically generated transcripts rely on software to make a guess about what's being said in your audio file. Your transcript will have more or less errors depending on the quality of the audio. For instance, broadcast-quality news productions and interviews recorded with high-quality equipment result in the most accurate transcripts because there is little background noise.",
				},
				{
					question: "What affects transcript quality?",
					answer: "Transcript quality may be adversely affected by the subject speaking quickly, with an accent, or mumbling; multiple speakers speaking at the same time; background noise; or background music tracks. Pop Up Archive also uses keyword extraction tools that pull useful terms from your transcripts, so even if your transcripts aren't perfect, we can still extract valuable information from them.",
				},
			]
		},
		{
			title: "Pop Up Archive Membership and Payment",
			link: "membership",
			questions: [
				{
					question: "Can I start with a monthly plan, and switch over to an annual plan?",
					answer: "If you start with a monthly plan and decide that you like Pop Up Archive enough to get our discounted annual rate, you can switch to an annual plan anytime. You will be charged the annual rate from the 1st day of the month after you changed plans.",
				},
				{
					question: "When and how am I charged?",
					answer: "For monthly plans, you’ll be charged once each month, on the first day of the month. If you sign up mid-month, you won't be charged until the 1st of the next month. For annual plans, you’ll be charged once a year on the first day of the month after you signed up. We use Stripe to process payments.",
				},
				{
					question: "What does “hours of processing” mean exactly?",
					answer: "Hours of processing refers to the hours of audio that you've uploaded to your Pop Up Archive collections. You can track how much you've uploaded from your account page. Each month, you can upload the amount of hours allocated to your plan, and we’ll automatically generate transcripts, tags. You’ll be able to access all your audio on our site as long as you’re a subscriber.",
				},
				{
					question: "Does the hourly limit reset each month?",
					answer: "Yes, you will be able to upload the number of hours available to your plan each month.",
				},
				{
					question: "Can I use Pop Up Archive for one-time processing?",
					answer: "Yes! If you'd like to use our services for one-time processing rather than on an on-going basis, you can sign up for a plan and downgrade to the free plan when your audio is processed. As long as you downgrade before the end of the calendar month, you will only be charged a pro-rated amount based on your usage and the plan rate. For example, you will be charged $30 for two hours of audio uploaded to the $75/mo five-hour plan. If you have more than 25 hours of audio, contact us at edison@popuparchive.com to get a quote for your audio collection."
				},
				{
					question: "I’d like for my whole audio team to use Pop Up Archive. Is there a team plan?",
					answer: "Yes, you can add multiple users to the Small Business and Enterprise plans. Email edison@popuparchive.com for more information."
				},
				{
					question: "Can I cancel at any time?",
					answer: "Yes, absolutely. When you're logged in, just click your user name, select “account,” then click “Change My Plan.” Choose the free Community Plan to downgrade your account. You will not be charged again unless you choose to upgrade. You have a 30 day grace period of access to audio processed while you were on a paid plan. In addition, all uploads to the Internet Archive will remain available at archive.org.",
				},
				// {
				// 	question: "What happens if I go over my hour limit?",
				// 	answer: "Don’t worry, you’ll receive an email from edison@popuparchive.com alerting you that you’ve reached your limit. You’ll be charged for any audio that you add over the set hourly limit.",
				// },
			]
		},
		{
			title: "Sharing Audio",
			link: "sharing_audio",
			questions: [
				{
					question: "How can I share an audio file from Pop Up Archive?",
					answer: "Click the social media buttons from any page on Pop Up Archive to share with your social networks. Got a blog? That’s what our embeddable player is for. Copy the html code from our “embed” button for an audio item, and paste it into the html on your WordPress, Tumblr, or other blog. For sites powered by WordPress, we also have a Pop Up Archive plugin that allows your to search your collections and integrate automatic tags right on your blog. Sign up or visit our Help Center for more information.",
				},
			]
		},
		{
			title: "Privacy",
			link: "privacy",
			questions: [
				{
					question: "What are public collections and where are they stored?",
					answer: "Media in public collections is visible to anyone on the web. Anyone can see or hear audio in public collections through Pop Up Archive’s website, which is indexed by Google like any other public website. Currently, no one can download material directly from the Pop Up Archive website unless they are an owner of the material. You can choose to store public collections either on Amazon S3 servers maintained by Pop Up Archive, or on servers at the Internet Archive (archive.org).",
				},
				{
					question: "What are private collections and where are they stored?",
					answer: "A private collection can be seen and heard only by the person who created it. Media in private collections is stored on private Amazon S3 servers maintained by Pop Up Archive. Private team collections (contact us if you're interested) can only be seen and heard by team members who have been granted access by the team administrator.",
				},
				{
					question: "What is the Internet Archive?",
					answer: "Like a public library, the Internet Archive stores media and makes it available at no cost to researchers, historians, and scholars. Public collections stored at the Internet Archive can be seen, heard, and downloaded through the Internet Archive's website, which is also indexed by Google.",
				},
				{
					question: "Who can access audio if it’s in a public collection?",
					answer: "Anyone can access audio in a public collection through Pop Up Archive’s website. No one can download material directly from Pop Up Archive website unless they are an owner of that material. If your public collection is stored at the Internet Archive, it can be accessed through Pop Up Archive’s website as well as through the Internet Archive. Audio stored at the Internet Archive can also be downloaded from the Internet Archive’s website.",
				},
				{
					question: "Who can access audio if it’s in a private collection?",
					answer: "A private collection can be seen and heard only by the person who created it. Private team collections are only visible to team members who have been granted access by the team administrator. Contact us if you're interested in creating a team collection.",
				},
			]
		},
	]
}]);
