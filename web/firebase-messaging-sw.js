// Service worker for Firebase Cloud Messaging on the web. Handles push
// payloads that arrive while the tab is not focused.
importScripts('https://www.gstatic.com/firebasejs/10.13.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyCTtqhat1bKpr0iV-t7MaAPulQsQur9gak',
  appId: '1:1048865733769:web:87fa18893c92af21e35a58',
  messagingSenderId: '1048865733769',
  projectId: 'ncti-schedule',
  authDomain: 'ncti-schedule.firebaseapp.com',
  storageBucket: 'ncti-schedule.firebasestorage.app',
  measurementId: 'G-CDV52D3014',
});

firebase.messaging();
