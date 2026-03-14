document.addEventListener('DOMContentLoaded', function() {
  const menuToggle = document.querySelector('.menu-toggle');
  const sidebar = document.getElementById('sidebar');
  const overlay = document.querySelector('.overlay');

  if (menuToggle) {
    menuToggle.addEventListener('click', function() {
      menuToggle.classList.toggle('active');
      sidebar.classList.toggle('open');
      overlay.classList.toggle('active');
    });
  }

  if (overlay) {
    overlay.addEventListener('click', function() {
      menuToggle.classList.remove('active');
      sidebar.classList.remove('open');
      overlay.classList.remove('active');
    });
  }
});
