const app = document.getElementById('app');
const barLabel = document.getElementById('barLabel');
const barFill = document.getElementById('barFill');

window.addEventListener('message', (event) => {
    const data = event.data;

    if (data.action === 'start') {
        barLabel.textContent = data.label || '';
        barFill.style.transitionDuration = '0ms';
        barFill.style.width = '0%';
        app.classList.remove('hidden');

        requestAnimationFrame(() => {
            requestAnimationFrame(() => {
                barFill.style.transitionDuration = `${data.duration}ms`;
                barFill.style.width = '100%';
            });
        });
    } else if (data.action === 'stop') {
        app.classList.add('hidden');
        barFill.style.transitionDuration = '0ms';
        barFill.style.width = '0%';
    }
});
