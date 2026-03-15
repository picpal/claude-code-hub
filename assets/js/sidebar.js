document.addEventListener('DOMContentLoaded', function() {
  const menuToggle = document.querySelector('.menu-toggle');
  const sidebar = document.getElementById('sidebar');
  const overlay = document.querySelector('.overlay');
  let scrollPosition = 0;

  function preventBodyScroll(e) {
    // 사이드바 내부 터치는 허용, 그 외(overlay/body)는 차단
    if (sidebar && sidebar.contains(e.target)) {
      // 사이드바가 스크롤 끝에 도달했을 때만 차단 (스크롤 체이닝 방지)
      var top = sidebar.scrollTop;
      var totalScroll = sidebar.scrollHeight;
      var currentScroll = top + sidebar.offsetHeight;
      if (top === 0) {
        sidebar.scrollTop = 1;
      } else if (currentScroll === totalScroll) {
        sidebar.scrollTop = top - 1;
      }
      return;
    }
    e.preventDefault();
  }

  function lockScroll() {
    scrollPosition = window.pageYOffset;
    document.body.style.overflow = 'hidden';
    document.body.style.position = 'fixed';
    document.body.style.top = '-' + scrollPosition + 'px';
    document.body.style.width = '100%';
    document.addEventListener('touchmove', preventBodyScroll, { passive: false });
  }

  function unlockScroll() {
    document.removeEventListener('touchmove', preventBodyScroll);
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
