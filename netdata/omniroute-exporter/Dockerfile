FROM python:3.12-alpine

WORKDIR /app
COPY exporter.py .

# No third-party deps — stdlib only
RUN python -c "import http.server, urllib.request, json, threading; print('deps ok')"

EXPOSE 9877

ENV OMNIROUTE_BASE_URL=https://omniroute.prod.sf.cktom.cyou
ENV EXPORTER_PORT=9877
ENV SCRAPE_INTERVAL=30

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:9877/metrics | grep -q omniroute_up || exit 1

CMD ["python", "exporter.py"]
