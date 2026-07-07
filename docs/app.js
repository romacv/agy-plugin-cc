document.addEventListener('DOMContentLoaded', () => {
    // Copy Command Functionality
    document.querySelectorAll('.copy-btn').forEach(btn => {
        btn.addEventListener('click', async () => {
            try {
                await navigator.clipboard.writeText(btn.dataset.copy.trim());
                const orig = btn.textContent;
                btn.textContent = 'Copied';
                btn.classList.add('copied');
                setTimeout(() => { 
                    btn.textContent = orig; 
                    btn.classList.remove('copied'); 
                }, 1400);
            } catch (e) { 
                btn.textContent = 'Press Cmd+C'; 
            }
        });
    });
});
