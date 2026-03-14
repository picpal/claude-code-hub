document.addEventListener('DOMContentLoaded', function() {
  if (typeof mermaid !== 'undefined') {
    mermaid.initialize({
      startOnLoad: true,
      theme: 'neutral',
      themeVariables: {
        primaryColor: '#7FB685',
        primaryTextColor: '#2D2D2D',
        lineColor: '#E8E4DF',
        secondaryColor: '#F3F0EB'
      }
    });
  }
});
