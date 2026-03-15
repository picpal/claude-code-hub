document.addEventListener('DOMContentLoaded', function() {
  const menuToggle = document.querySelector('.menu-toggle');
  const sidebar = document.getElementById('sidebar');
  const overlay = document.querySelector('.overlay');
  let scrollPosition = 0;

  function lockScroll() {
    scrollPosition = window.pageYOffset;
    document.body.style.overflow = 'hidden';
    document.body.style.position = 'fixed';
    document.body.style.top = '-' + scrollPosition + 'px';
    document.body.style.width = '100%';
  }

  function unlockScroll() {
    document.body.style.removeProperty('overflow');
    document.body.style.removeProperty('position');
    document.body.style.removeProperty('top');
    document.body.style.removeProperty('width');
    window.scrollTo(0, scrollPosition);
  }

  if (menuToggle) {
    menuToggle.addEventListener('click', function() {
      const isOpen = sidebar.classList.toggle('open');
      menuToggle.classList.toggle('active');
      overlay.classList.toggle('active');
      if (isOpen) {
        lockScroll();
      } else {
        unlockScroll();
      }
    });
  }

  if (overlay) {
    overlay.addEventListener('click', function() {
      menuToggle.classList.remove('active');
      sidebar.classList.remove('open');
      overlay.classList.remove('active');
      unlockScroll();
    });
  }
});
